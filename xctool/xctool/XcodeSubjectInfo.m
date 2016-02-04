//
// Copyright 2004-present Facebook. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "XcodeSubjectInfo.h"

#import "Buildable.h"
#import "PbxprojReader.h"
#import "TaskUtil.h"
#import "Testable.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"
#import "XcodeTargetMatch.h"

// We consider a DerivedData "recently modified" within this interval.
static const NSTimeInterval RECENTLY_MODIFIED_DERIVED_DATA_INTERVAL = 60 * 15;

static NSString *StringByStandardizingPath(NSString *path)
{
  NSMutableArray *stack = [NSMutableArray array];
  for (NSString *component in [path pathComponents]) {
    if ([component isEqualToString:@"."]) {
      // skip
    } else if ([component isEqualToString:@".."] && stack.count > 0 && ![[stack lastObject] isEqualToString:@".."]) {
      [stack removeLastObject];
      continue;
    } else if ([component isEqualToString:@"/"]) {
      [stack addObject:@""];
    } else {
      [stack addObject:component];
    }
  }
  return [stack componentsJoinedByString:@"/"];
}

static NSString *ProjectPathFromSchemePath(NSString *schemePath)
{
  for (;;) {
    NSCAssert(schemePath.length > 0, @"Scheme path length should be more then 0: %@", schemePath);

    if ([schemePath hasSuffix:@".xcodeproj"] || [schemePath hasSuffix:@".xcworkspace"]) {
      break;
    }

    schemePath = [schemePath stringByDeletingLastPathComponent];
  }

  if (schemePath.length == 0) {
    schemePath = @".";
  }

  return schemePath;
}

static NSString *FullPathForBasePathAndRelativePath(NSString *basePath, NSString *relativePath)
{
  NSString *fullPath = [basePath stringByAppendingPathComponent:relativePath];
  NSArray *relativePathComponenets = [relativePath pathComponents];
  for (NSUInteger l=[relativePathComponenets count]; l>0; l--) {
    NSString *substring = [NSString pathWithComponents:[relativePathComponenets subarrayWithRange:NSMakeRange(0, l)]];
    if ([basePath hasSuffix:substring]) {
      fullPath = [basePath stringByAppendingPathComponent:[relativePath substringFromIndex:[substring length]]];
      break;
    }
  }
  return fullPath;
}

static NSString *StandardizedContainerPath(NSString *container, NSString *basePath)
{
  static NSString * const kContainerReference = @"container:";
  NSCAssert([container hasPrefix:kContainerReference], @"Container has unexpected prefix: %@; expected: %@", container, kContainerReference);
  NSString *containerPath = [container substringFromIndex:kContainerReference.length];
  return StringByStandardizingPath([basePath stringByAppendingPathComponent:containerPath]);
}

static NSString *SchemeProjectDirectoryPath(NSString *schemePath)
{
  return ProjectBaseDirectoryPath(ProjectPathFromSchemePath(schemePath));
}

static NSDictionary *BuildConfigurationsByActionForSchemePath(NSString *schemePath)
{
  NSError *error = nil;
  NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:schemePath]
                                                             options:0
                                                               error:&error];
  if (error != nil) {
    NSLog(@"Error in parsing: %@: %@", schemePath, error);
    abort();
  }

  NSArray *actionNodeNames = @[@"LaunchAction",
                               @"TestAction",
                               @"ArchiveAction",
                               @"ProfileAction",
                               @"AnalyzeAction",
                               ];
  NSMutableDictionary *results = [NSMutableDictionary dictionary];

  for (NSString *actionNodeName in actionNodeNames) {
    NSArray *actionNodes = [doc nodesForXPath:[@"//" stringByAppendingString:actionNodeName]
                                        error:nil];
    NSCAssert([actionNodes count] == 1,
              @"Should have gotten exactly one node, but got: %@", actionNodes);

    NSXMLElement *actionNode = actionNodes[0];

    NSString *configuration = [[actionNode attributeForName:@"buildConfiguration"] stringValue];
    NSCAssert(configuration != nil, @"Should have a 'buildConfiguration'");

    results[actionNodeName] = configuration;
  }

  return results;
}

@interface XcodeSubjectInfo ()
@property (nonatomic, copy) NSDictionary *configurationNameByAction;
@end

@implementation XcodeSubjectInfo

+ (NSArray *)projectPathsInWorkspace:(NSString *)workspacePath
{
  NSString *workspaceBasePath = [workspacePath stringByDeletingLastPathComponent];
  if (workspaceBasePath.length == 0) {
    workspaceBasePath = @".";
  }

  NSString *path = [workspacePath stringByAppendingPathComponent:@"contents.xcworkspacedata"];
  if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
    // Git might leave empty directories around with no workspace data.
    return @[];
  }

  NSURL *URL = [NSURL fileURLWithPath:path];
  NSError *error = nil;
  NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:URL
                                                            options:0
                                                              error:&error];
  if (error != nil) {
    NSLog(@"Error in parsing: %@: %@", workspacePath, error);
    abort();
  }

  __block __weak NSString *(^weak_fullLocation)(NSXMLNode*, NSString *);
  NSString *(^fullLocation)(NSXMLNode*, NSString *);
  weak_fullLocation = fullLocation = ^(NSXMLNode *node, NSString *containerPath) {

    if (node == nil || ![@[@"FileRef", @"Group", @"Workspace"] containsObject:node.name]) {
      return @"";
    }

    if ([node.name isEqualToString:@"Workspace"]) {
      return containerPath;
    }

    NSString *location = [[(NSXMLElement *)node attributeForName:@"location"] stringValue];
    NSRange colonRange = [location rangeOfString:@":"];
    NSString *locationAfterColon = [location substringFromIndex:colonRange.location + 1];

    if ([location hasPrefix:@"container:"]) {
      return [containerPath stringByAppendingPathComponent:locationAfterColon];
    } else if ([location hasPrefix:@"group:"]) {
      return [weak_fullLocation(node.parent, containerPath) stringByAppendingPathComponent:locationAfterColon];
    } else if ([location hasPrefix:@"self:"]) {
      NSCAssert([[workspacePath lastPathComponent] isEqualToString:@"project.xcworkspace"],
                @"We only expect to see 'self:' in workspaces nested in xcodeproj's.");
      // Go from path/to/SomeProj.xcodeproj/contents.xcworkspace -> path/to
      NSString *path = [workspaceBasePath stringByDeletingLastPathComponent];
      return [path stringByAppendingPathComponent:locationAfterColon];
    } else {
      [NSException raise:NSGenericException format:@"Unexpection location in workspace '%@'", location];
      return (NSString *)nil;
    }
  };

  NSArray *fileRefNodes = [doc nodesForXPath:@"//FileRef" error:nil];
  NSMutableArray *rootProjectFiles = [NSMutableArray array];
  for (NSXMLElement *node in fileRefNodes) {
    NSString *location = [[node attributeForName:@"location"] stringValue];

    if ([location hasSuffix:@".xcodeproj"]) {
      [rootProjectFiles addObject:StringByStandardizingPath(fullLocation(node, workspaceBasePath))];
    }
  }
  NSMutableSet *projectFiles = [NSMutableSet setWithArray:rootProjectFiles];
  for (NSString *projectFilePath in rootProjectFiles) {
    [projectFiles unionSet:[self projectPathsInProject:projectFilePath]];
  }

  return [projectFiles allObjects];
}

+ (NSSet *)projectPathsInProject:(NSString *)projectPath
{
  NSMutableSet *projects = [ProjectFilesReferencedInProjectAtPath(projectPath) mutableCopy];
  for (NSString *innerProjectPath in [projects allObjects]) {
    [projects unionSet:[self projectPathsInProject:innerProjectPath]];
  }
  return projects;
}

+ (NSArray *)schemePathsInWorkspace:(NSString *)workspace
{
  NSMutableArray *schemes = [NSMutableArray array];

  for (NSString *projectPath in [XcodeSubjectInfo projectPathsInWorkspace:workspace]) {
    [schemes addObjectsFromArray:[XcodeSubjectInfo schemePathsInContainer:projectPath]];
  }

  [schemes addObjectsFromArray:[XcodeSubjectInfo schemePathsInContainer:workspace]];

  return schemes;
}

+ (NSArray *)schemePathsInContainer:(NSString *)project
{
  NSMutableArray *schemes = [NSMutableArray array];
  NSFileManager *fm = [NSFileManager defaultManager];

  // Collect shared schemes (those that have 'Shared' checked in the Schemes Manager).
  NSString *sharedSchemesPath = [project stringByAppendingPathComponent:@"xcshareddata/xcschemes"];
  NSArray *sharedContents = [fm contentsOfDirectoryAtPath:sharedSchemesPath
                                                    error:nil];
  if (sharedContents != nil) {
    for (NSString *file in sharedContents) {
      if ([file hasSuffix:@".xcscheme"]) {
        [schemes addObject:[sharedSchemesPath stringByAppendingPathComponent:file]];
      }
    }
  }

  // Collect user-specific schemes.
  NSString *currentlyLoggedInUserSchemesPath = [NSString pathWithComponents:@[
    [project stringByAppendingPathComponent:@"xcuserdata"],
    [NSUserName() stringByAppendingPathExtension:@"xcuserdatad"],
    @"xcschemes"
  ]];
  if ([fm fileExistsAtPath:currentlyLoggedInUserSchemesPath]) {
    NSArray *userSchemesContents = [fm contentsOfDirectoryAtPath:currentlyLoggedInUserSchemesPath error:nil];
    for (NSString *file in userSchemesContents) {
      if ([file hasSuffix:@".xcscheme"]) {
        [schemes addObject:[currentlyLoggedInUserSchemesPath stringByAppendingPathComponent:file]];
      }
    }
  }

  return schemes;
}

+ (BOOL)         directory:(NSURL *)dirURL
containsFilesModifiedSince:(NSDate *)sinceDate
              modifiedDate:(NSDate **)modifiedDate
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDirectoryEnumerator *dirEnum = [fm enumeratorAtURL:dirURL
                            includingPropertiesForKeys:@[NSURLContentModificationDateKey]
                                               options:0
                                          errorHandler:NULL];
  for (NSURL *url in dirEnum) {
    NSDate *modificationDate;
    [url getResourceValue:&modificationDate forKey:NSURLContentModificationDateKey error:NULL];

    if (modificationDate &&
        [modificationDate compare:sinceDate] == NSOrderedDescending) {
      *modifiedDate = modificationDate;
      return YES;
    }
  }

  return NO;
}

+ (BOOL)findWorkspacePathForDerivedDataURL:(NSURL *)derivedDataWorkspaceURL
                             workspacePath:(NSString **)workspacePath
{
  NSFileManager *fm = [NSFileManager defaultManager];

  // Yes, Xcode really uses lower-case "i" for the info.plist inside a DerivedData subdirectory.
  NSURL *infoPlistURL = [derivedDataWorkspaceURL URLByAppendingPathComponent:@"info.plist"];

  NSDictionary *workspaceInfoPlist =
    [NSDictionary dictionaryWithContentsOfFile:[infoPlistURL path]];
  NSString *result = workspaceInfoPlist[@"WorkspacePath"];

  if ([fm fileExistsAtPath:result]) {
    *workspacePath = result;
    return YES;
  } else {
    return NO;
  }
}

+ (NSArray *)workspacePathsForRelativeDerivedDataURL:(NSURL *)derivedDataWorkspaceURL
{
  NSFileManager *fm = [NSFileManager defaultManager];

  NSMutableArray *result = [NSMutableArray array];

  NSArray *derivedDataContentURLs = [fm contentsOfDirectoryAtURL:derivedDataWorkspaceURL
                                      includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                         options:0
                                                           error:NULL];
  for (NSURL *url in derivedDataContentURLs) {
    NSNumber *isDirectory;
    [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
    if (![isDirectory boolValue]) {
      continue;
    }

    NSString *workspacePath;
    if ([self findWorkspacePathForDerivedDataURL:url
                                   workspacePath:&workspacePath]) {
      [result addObject:workspacePath];
    }
  }

  return result;
}

+ (NSDictionary *)workspacePathsModifiedSince:(NSDate *)sinceDate
                                  inDirectory:(NSString *)directory
                                 excludePaths:(NSArray *)excludePaths
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSMutableDictionary *workspacePathModifyDates = [NSMutableDictionary dictionary];

  NSDictionary *xcodePrefs = [NSDictionary dictionaryWithContentsOfFile:
    [@"~/Library/Preferences/com.apple.dt.Xcode.plist" stringByExpandingTildeInPath]];
  NSString *derivedDataLocation = xcodePrefs[@"IDECustomDerivedDataLocation"] ?:
    [@"~/Library/Developer/Xcode/DerivedData" stringByExpandingTildeInPath];

  // This location might be absolute or relative. If relative, we have to search under
  // the directory for the specified DerivedData paths.
  if ([derivedDataLocation isAbsolutePath]) {
    NSURL *dirURL = [NSURL fileURLWithPath:derivedDataLocation isDirectory:YES];
    NSArray *derivedDataWorkspaceURLs = [fm contentsOfDirectoryAtURL:dirURL
                                          includingPropertiesForKeys:@[]
                                                             options:0
                                                               error:NULL];
    for (NSURL *derivedDataWorkspaceURL in derivedDataWorkspaceURLs) {
      NSDate *modifiedDate;
      if ([self                 directory:derivedDataWorkspaceURL
               containsFilesModifiedSince:sinceDate
                             modifiedDate:&modifiedDate]) {
        NSString *workspacePath;
        if ([self findWorkspacePathForDerivedDataURL:derivedDataWorkspaceURL
                                       workspacePath:&workspacePath]) {
          workspacePathModifyDates[workspacePath] = modifiedDate;
        }
      }
    }
  } else {
    NSURL *dirURL = [NSURL fileURLWithPath:directory isDirectory:YES];
    NSDirectoryEnumerator *dirEnum = [fm enumeratorAtURL:dirURL
                                         includingPropertiesForKeys:@[NSURLNameKey, NSURLContentModificationDateKey]
                                                 options:0
                                            errorHandler:NULL];
    for (NSURL *url in dirEnum) {
      NSString *fileName;
      [url getResourceValue:&fileName forKey:NSURLNameKey error:NULL];

      if ([excludePaths containsObject:fileName]) {
        [dirEnum skipDescendents];
        continue;
      }

      if (![fileName isEqualToString:derivedDataLocation]) {
        continue;
      }

      NSDate *modifiedDate;
      if ([self                  directory:url
                containsFilesModifiedSince:sinceDate
                              modifiedDate:&modifiedDate]) {
        NSArray *workspacePaths = [self workspacePathsForRelativeDerivedDataURL:url];
        for (NSString *workspacePath in workspacePaths) {
          workspacePathModifyDates[workspacePath] = modifiedDate;
        }
      }
    }
  }

  return workspacePathModifyDates;
}

+ (BOOL)findTarget:(NSString *)target
       inDirectory:(NSString *)directory
      excludePaths:(NSArray *)excludePaths
   bestTargetMatch:(XcodeTargetMatch **)bestTargetMatchOut
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSURL *dirURL = [NSURL fileURLWithPath:directory isDirectory:YES];
  NSDirectoryEnumerator *dirEnum =
            [fm enumeratorAtURL:dirURL
     includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                        options:0
                    errorHandler:NULL];

  XcodeTargetMatch *bestTargetMatch = nil;

  NSDictionary *recentlyModifiedWorkspaces =
    [self workspacePathsModifiedSince:[NSDate dateWithTimeIntervalSinceNow:-1 * RECENTLY_MODIFIED_DERIVED_DATA_INTERVAL]
                          inDirectory:directory
                         excludePaths:excludePaths];

  for (NSURL *url in dirEnum) {
    NSString *fileName;
    [url getResourceValue:&fileName forKey:NSURLNameKey error:NULL];
    NSNumber *isDirectory;
    [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
    if (![isDirectory boolValue]) {
      continue;
    }

    if ([excludePaths containsObject:fileName]) {
      [dirEnum skipDescendents];
      continue;
    }

    NSString *extension = [fileName pathExtension];
    BOOL isWorkspace = [extension isEqualToString:@"xcworkspace"];
    BOOL isProject = [extension isEqualToString:@"xcodeproj"];
    if (!isWorkspace && !isProject) {
      continue;
    }

    if (isProject) {
      // Workspaces can have projects inside, but not vice-versa.
      [dirEnum skipDescendents];
    }

    NSArray *targetMatches = nil;

    NSString *containerPath = [url path];
    NSMutableSet *schemePathsSet =
      [NSMutableSet setWithArray:[self schemePathsInContainer:containerPath]];

    if (isWorkspace) {
      for (NSString *projectPath in [self projectPathsInWorkspace:containerPath]) {
        [schemePathsSet addObjectsFromArray:[self schemePathsInContainer:projectPath]];
      }
    }

    if ([self findTarget:target
           inSchemePaths:[schemePathsSet allObjects]
           targetMatches:&targetMatches]) {
      NSDate *recentlyModifiedWorkspaceDate =
        recentlyModifiedWorkspaces[containerPath];

      for (XcodeTargetMatch *targetMatch in targetMatches) {
        BOOL betterMatch;
        if (!bestTargetMatch) {
          betterMatch = YES;
        } else if (recentlyModifiedWorkspaceDate && !bestTargetMatch.recentlyModifiedWorkspaceDate) {
          betterMatch = YES;
        } else if (recentlyModifiedWorkspaceDate &&
                   [recentlyModifiedWorkspaceDate compare:bestTargetMatch.recentlyModifiedWorkspaceDate] == NSOrderedDescending) {
          betterMatch = YES;
        } else if (targetMatch.numTargetsInScheme < bestTargetMatch.numTargetsInScheme) {
          betterMatch = YES;
        } else if (isWorkspace && !bestTargetMatch.workspacePath) {
          betterMatch = YES;
        } else {
          betterMatch = NO;
        }

        if (betterMatch) {
          bestTargetMatch = targetMatch;
          if (isWorkspace) {
            bestTargetMatch.workspacePath = containerPath;
            if (recentlyModifiedWorkspaceDate) {
              bestTargetMatch.recentlyModifiedWorkspaceDate = recentlyModifiedWorkspaceDate;
            }
          } else if (isProject) {
            bestTargetMatch.projectPath = containerPath;
          }
        }
      }
    }
  }

  if (bestTargetMatch) {
    *bestTargetMatchOut = bestTargetMatch;
    return YES;
  } else {
    return NO;
  }
}


+ (BOOL)   findTarget:(NSString *)target
        inSchemePaths:(NSArray *)schemePaths
        targetMatches:(NSArray **)targetMatchesOut {
  BOOL found = NO;
  NSMutableArray *targetMatches = [NSMutableArray array];

  for (NSString *schemePath in schemePaths) {
    NSArray *testables = [self testablesInSchemePath:schemePath
                                            basePath:SchemeProjectDirectoryPath(schemePath)];
    NSArray *buildables = [self buildablesInSchemePath:schemePath
                                              basePath:SchemeProjectDirectoryPath(schemePath)];
    for (Testable *testable in [testables arrayByAddingObjectsFromArray:buildables]) {
      if ([testable.target isEqualToString:target]) {
        found = YES;
        XcodeTargetMatch *match = [[XcodeTargetMatch alloc] init];
        match.schemeName = [[schemePath lastPathComponent] stringByDeletingPathExtension];
        match.numTargetsInScheme = [self numTargetsInSchemePath:schemePath];
        [targetMatches addObject:match];
      }
    }
  }

  if (found) {
    *targetMatchesOut = targetMatches;
  }
  return found;
}

+ (NSUInteger)numTargetsInSchemePath:(NSString *)schemePath
{
  NSError *error = nil;
  NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:schemePath]
                                                             options:0
                                                               error:&error];
  if (error != nil) {
    NSLog(@"Error in parsing: %@: %@", schemePath, error);
    abort();
  }

  NSArray *buildActionEntryNodes = [doc nodesForXPath:@"//BuildActionEntry" error:nil];
  return [buildActionEntryNodes count];
}

/**
 Returns the arguments and environment settings that tests should be run with.
 Depending on how the scheme is configured, these will either be specified as
 part of the 'Run' action (default) or 'Test' action.
 */
+ (NSDictionary *)argumentsAndEnvironmentForTestAction:(NSXMLDocument *)doc
                                              basePath:(NSString *)basePath
{
  NSError *error = nil;

  NSArray *testActionNodes = [doc nodesForXPath:@"//TestAction" error:&error];
  NSAssert(error == nil, @"Failed to get nodes: %@", [error localizedFailureReason]);
  NSAssert([testActionNodes count] == 1,
           @"Should only have 1 test action but had: %@", testActionNodes);

  BOOL shouldUseLaunchSchemeArgsEnv =
    [[[testActionNodes[0] attributeForName:@"shouldUseLaunchSchemeArgsEnv"] stringValue]
     isEqualToString:@"YES"];
  NSString *searchAction = shouldUseLaunchSchemeArgsEnv ? @"LaunchAction" : @"TestAction";

  NSArray *commandLineArgumentNodes =
    [doc nodesForXPath:[NSString stringWithFormat:@"//%@//CommandLineArgument",
                        searchAction]
                 error:&error];
  NSAssert(error == nil, @"Failed to get nodes: %@", [error localizedFailureReason]);
  NSArray *environmentVariableNodes =
    [doc nodesForXPath:[NSString stringWithFormat:@"//%@//EnvironmentVariable",
                        searchAction]
                 error:&error];
  NSAssert(error == nil, @"Failed to get nodes: %@", [error localizedFailureReason]);

  NSArray *macroExpansionBuildableReferenceNodes =
    [doc nodesForXPath:[NSString stringWithFormat:@"//%@//MacroExpansion/BuildableReference",
                        searchAction]
                 error:&error];
  NSAssert(error == nil, @"Failed to get nodes: %@", [error localizedFailureReason]);
  NSAssert([macroExpansionBuildableReferenceNodes count] == 0 ||
           [macroExpansionBuildableReferenceNodes count] == 1,
           @"Should only have 0 or 1 macro expansion nodes: %@",
           macroExpansionBuildableReferenceNodes);

  NSArray *buildableProductRunnableRefNodes =
    [doc nodesForXPath:@"//LaunchAction/BuildableProductRunnable/BuildableReference"
                 error:&error];
  NSAssert(error == nil, @"Failed to get nodes: %@", [error localizedFailureReason]);

  NSMutableString* combinedArgumentsString = [NSMutableString string];
  for (NSXMLElement *node in commandLineArgumentNodes) {
    NSString *argumentString = [[node attributeForName:@"argument"] stringValue];
    BOOL isEnabled = [[[node attributeForName:@"isEnabled"] stringValue] isEqualToString:@"YES"];
    if (isEnabled) {
      if (combinedArgumentsString.length > 0) {
        [combinedArgumentsString appendString:@" "];
      }
      [combinedArgumentsString appendString:argumentString];
    }
  }
  NSArray* arguments = ParseArgumentsFromArgumentString(combinedArgumentsString);

  NSMutableDictionary *environment = [NSMutableDictionary dictionary];
  for (NSXMLElement *node in environmentVariableNodes) {
    NSString *key = [[node attributeForName:@"key"] stringValue];
    NSString *value = [[node attributeForName:@"value"] stringValue];
    BOOL isEnabled = [[[node attributeForName:@"isEnabled"] stringValue] isEqualToString:@"YES"];

    if (isEnabled) {
      environment[key] = value;
    }
  }

  NSString *macroExpansionProjectPath = nil;
  NSString *macroExpansionTarget = nil;

  if ([macroExpansionBuildableReferenceNodes count] > 0) {
    NSString *macroExpansionProjectReferencedContainer =
      [[macroExpansionBuildableReferenceNodes[0] attributeForName:@"ReferencedContainer"] stringValue];

    NSString *projectPath = StandardizedContainerPath(macroExpansionProjectReferencedContainer, basePath);
    if ([[NSFileManager defaultManager] fileExistsAtPath:projectPath]) {
      macroExpansionProjectPath = projectPath;
      macroExpansionTarget = [[macroExpansionBuildableReferenceNodes[0]
                               attributeForName:@"BlueprintName"] stringValue];
    }
  } else if ([macroExpansionBuildableReferenceNodes count] == 0 &&
             shouldUseLaunchSchemeArgsEnv &&
             [buildableProductRunnableRefNodes count] > 0) {
    // In the Run action, if the target being run is an executable (or perhaps,
    // just not a library), then it's implied that macro expansion is enabled
    // and uses the build settings of that target.
    NSAssert([buildableProductRunnableRefNodes count] == 1,
             @"Should have found 1 BuildableProductRunnable node which has 1 "
             @"BuildableReference node.");

    NSString *referencedContainer =
      [[buildableProductRunnableRefNodes[0] attributeForName:@"ReferencedContainer"] stringValue];
    NSString *projectPath = StandardizedContainerPath(referencedContainer, basePath);
    if ([[NSFileManager defaultManager] fileExistsAtPath:projectPath]) {
      macroExpansionProjectPath = projectPath;
      macroExpansionTarget = [[buildableProductRunnableRefNodes[0] attributeForName:@"BlueprintName"] stringValue];
    }
  }

  return @{
           @"arguments" : arguments,
           @"environment" : environment,
           @"macroExpansionProjectPath" : macroExpansionProjectPath ?: [NSNull null],
           @"macroExpansionTarget" : macroExpansionTarget ?: [NSNull null],
           };
}

+ (NSArray *)testablesInSchemePath:(NSString *)schemePath basePath:(NSString *)basePath
{
  NSError *error = nil;
  NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:schemePath]
                                                             options:0
                                                               error:&error];
  if (error != nil) {
    NSLog(@"Error in parsing: %@: %@", schemePath, error);
    abort();
  }

  NSDictionary *argumentsAndEnvironment = [self argumentsAndEnvironmentForTestAction:doc
                                                                            basePath:basePath];

  NSArray *testableReferenceNodes = [doc nodesForXPath:@"//TestableReference" error:nil];

  NSMutableArray *testables = [NSMutableArray array];

  for (NSXMLElement *node in testableReferenceNodes) {
    BOOL skipped =
      [[[node attributeForName:@"skipped"] stringValue] isEqualToString:@"YES"] ? YES : NO;
    NSArray *buildableReferences = [node nodesForXPath:@"BuildableReference" error:nil];

    NSAssert(buildableReferences.count == 1, @"Number of buildable references should be 1: %@", buildableReferences);
    NSXMLElement *buildableReference = buildableReferences[0];

    NSString *referencedContainer = [[buildableReference attributeForName:@"ReferencedContainer"] stringValue];
    NSString *projectPath = StandardizedContainerPath(referencedContainer, basePath);
    if (![[NSFileManager defaultManager] fileExistsAtPath:projectPath]) {
      // Skipping reference to a non-existing project same way as xcodebuild does
      continue;
    }

    NSString *executable = [[buildableReference attributeForName:@"BuildableName"] stringValue];
    NSString *target = [[buildableReference attributeForName:@"BlueprintName"] stringValue];
    NSString *targetID = [[buildableReference attributeForName:@"BlueprintIdentifier"] stringValue];

    NSArray *skippedTestsNodes = [node nodesForXPath:@"SkippedTests/Test" error:nil];
    NSMutableArray *testsToSkip = [NSMutableArray array];
    for (NSXMLElement *node in skippedTestsNodes) {
      NSString *test = [[node attributeForName:@"Identifier"] stringValue];
      [testsToSkip addObject:test];
    }

    Testable *testable = [[Testable alloc] init];
    testable.projectPath = projectPath;
    testable.target = target;
    testable.targetID = targetID;
    testable.executable = executable;
    testable.skippedTests = testsToSkip;
    testable.skipped = skipped;
    testable.arguments = argumentsAndEnvironment[@"arguments"];
    testable.environment = argumentsAndEnvironment[@"environment"];
    testable.macroExpansionProjectPath = ([argumentsAndEnvironment[@"macroExpansionProjectPath"] isEqualTo:[NSNull null]]) ?
                                          nil : argumentsAndEnvironment[@"macroExpansionProjectPath"];
    testable.macroExpansionTarget = ([argumentsAndEnvironment[@"macroExpansionTarget"] isEqualTo:[NSNull null]]) ?
                                     nil : argumentsAndEnvironment[@"macroExpansionTarget"];
    [testables addObject:testable];
  }

  return testables;
}

+ (NSArray *)buildablesInSchemePath:(NSString *)schemePath basePath:(NSString *)basePath
{
  NSError *error = nil;
  NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:schemePath]
                                                             options:0
                                                               error:&error];
  if (error != nil) {
    NSLog(@"Error in parsing: %@: %@", schemePath, error);
    abort();
  }

  NSArray *buildActionEntryNodes =
  [doc nodesForXPath:@"//BuildActionEntry[@buildForTesting='YES' or @buildForRunning='YES' or @buildForAnalyzing='YES']"
               error:nil];

  NSMutableArray *buildables = [NSMutableArray array];
  for (NSXMLElement *node in buildActionEntryNodes) {
    NSArray *buildableReferences = [node nodesForXPath:@"BuildableReference" error:nil];

    NSAssert(buildableReferences.count == 1, @"Number of buildable references should be 1: %@", buildableReferences);
    NSXMLElement *buildableReference = buildableReferences[0];

    NSString *referencedContainer = [[buildableReference attributeForName:@"ReferencedContainer"] stringValue];
    NSString *projectPath = StandardizedContainerPath(referencedContainer, basePath);
    if (![[NSFileManager defaultManager] fileExistsAtPath:projectPath]) {
      // Skipping reference to a non-existing project same way as xcodebuild does
      continue;
    }

    NSString *target = [[buildableReference attributeForName:@"BlueprintName"] stringValue];
    NSString *targetID = [[buildableReference attributeForName:@"BlueprintIdentifier"] stringValue];
    NSString *executable = [[buildableReference attributeForName:@"BuildableName"] stringValue];

    BOOL forRunning = [[[node attributeForName:@"buildForRunning"] stringValue] isEqual:@"YES"];
    BOOL forTesting = [[[node attributeForName:@"buildForTesting"] stringValue] isEqual:@"YES"];
    BOOL forAnalyzing = [[[node attributeForName:@"buildForAnalyzing"] stringValue] isEqual:@"YES"];

    Buildable *buildable = [[Buildable alloc] init];
    buildable.projectPath = projectPath;
    buildable.target = target;
    buildable.targetID = targetID;
    buildable.executable = executable;
    buildable.buildForRunning = forRunning;
    buildable.buildForTesting = forTesting;
    buildable.buildForAnalyzing = forAnalyzing;

    [buildables addObject:buildable];
  }

  return buildables;
}

/**
 Returns build settings for some target in the scheme.  We don't actually care
 which target's settings are returned, since we only need a few specific values:
 OBJROOT, SYMROOT, SHARED_PRECOMPS_DIR, and EFFECTIVE_PLATFORM_NAME.

 If we knew more about Xcode internals, we could probably find a way to query
 these values without calling -showBuildSettings.
 */
- (NSDictionary *)buildSettingsForATarget
{
  NSDictionary *(^buildSettingsWithAction)(NSString *, NSString **) = ^(NSString *action, NSString **error) {
    NSTask *task = CreateTaskInSameProcessGroup();
    [task setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"]];
    [task setArguments:
     [_subjectXcodeBuildArguments arrayByAddingObjectsFromArray:@[action, @"-showBuildSettings"]]];
    [task setEnvironment:@{
                           @"DYLD_INSERT_LIBRARIES" :
                             [XCToolLibPath() stringByAppendingPathComponent:
                              @"xcodebuild-fastsettings-shim.dylib"],
                           @"SHOW_ONLY_BUILD_SETTINGS_FOR_FIRST_BUILDABLE" : @"YES"
                           }];

    NSDictionary *result = LaunchTaskAndCaptureOutput(task, @"gathering build settings for a target");

    if (error) {
      *error = result[@"stderr"];
    }

    return BuildSettingsFromOutput(result[@"stdout"]);
  };

  // Starting with Xcode 5+, -showBuildSettings is action-dependent.  If you run
  // `build -showBuildSettings`, it returns build settings for targets in the scheme
  // that are marked buildForRunning=YES.  If you run `test -showBuildSettings`,
  // it returns build settings for targets that are marked buildForTesting=YES.
  //
  // This can cause a problem.  Suppose you had a scheme with only 1 target, and
  // that target was a test bundle.  (i.e. no targets are marked as
  // buildForRunning=YES).  If you were to run `build -showBuildSettings` on this
  // scheme, xcodebuild would give you nothing since no targets are marked as
  // build for running.
  //
  // As a workaround for this, we're going to call `-showBuildSettings` with
  // a few different actions until we get one that works.  For our limited purposes,
  // it doesn't really matter which one works.
  NSArray *actionsToTry = @[@"build", @"test", @"analyze"];

  NSString *errors = @" Errors above occured while running xcodebuild -showBuildSettings:\n";
  BOOL errored = NO;
  for (NSString *action in actionsToTry) {
    NSString *error = nil;
    NSDictionary *settings = buildSettingsWithAction(action, &error);

    if (settings.count == 1) {
      return settings;
    }

    if (error) {
      errored = YES;
      errors = [errors stringByAppendingFormat:@"  %@.\n", error];
    }
  }

  NSAssert(NO, @"Failed while trying to gather build settings for your scheme; "
               @"tried with actions: %@.%@", [actionsToTry componentsJoinedByString:@", "],
                                             errored ? errors : @"");
  return nil;
}

- (NSString *)matchingSchemePathForWorkspace
{
  NSString *matchingSchemePath = nil;

  NSArray *schemePaths = [XcodeSubjectInfo schemePathsInWorkspace:_subjectWorkspace];
  for (NSString *schemePath in schemePaths) {
    if ([schemePath hasSuffix:[NSString stringWithFormat:@"/%@.xcscheme", _subjectScheme]]) {
      matchingSchemePath = schemePath;
    }
  }

  return matchingSchemePath;
}

- (NSString *)matchingSchemePathForProject
{
  NSString *matchingSchemePath = nil;

  NSArray *schemePaths = [XcodeSubjectInfo schemePathsInContainer:_subjectProject];
  for (NSString *schemePath in schemePaths) {
    if ([schemePath hasSuffix:[NSString stringWithFormat:@"/%@.xcscheme", _subjectScheme]]) {
      matchingSchemePath = schemePath;
    }
  }

  return matchingSchemePath;
}

- (void)populateBuildablesAndTestablesForWorkspaceWithSchemePath:(NSString *)schemePath
{
  _testables = [[self class] testablesInSchemePath:schemePath
                                          basePath:SchemeProjectDirectoryPath(schemePath)];
  _buildables = [[self class] buildablesInSchemePath:schemePath
                                            basePath:SchemeProjectDirectoryPath(schemePath)];

  _buildablesForTest = [_buildables objectsAtIndexes:
                        [_buildables indexesOfObjectsPassingTest:
                         ^BOOL(Buildable *obj, NSUInteger idx, BOOL *stop) {
                           return obj.buildForTesting;
                         }]];
}

- (void)populateBuildablesAndTestablesForProjectWithSchemePath:(NSString *)schemePath
{
  _testables = [[self class] testablesInSchemePath:schemePath
                                          basePath:SchemeProjectDirectoryPath(schemePath)];

  _buildables = [[self class] buildablesInSchemePath:schemePath
                                            basePath:SchemeProjectDirectoryPath(schemePath)];
  _buildablesForTest = [_buildables objectsAtIndexes:
                        [_buildables indexesOfObjectsPassingTest:
                         ^BOOL(Buildable *obj, NSUInteger idx, BOOL *stop) {
                           return obj.buildForTesting;
                         }]];
}

- (void)populateBuildActionPropertiesWithSchemePath:(NSString *)schemePath
{
  NSError *error = nil;
  NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:schemePath]
                                                             options:0
                                                               error:&error];
  if (error != nil) {
    NSLog(@"Error in parsing: %@: %@", schemePath, error);
    abort();
  }

  NSArray *buildActionNodes = [doc nodesForXPath:@"//BuildAction" error:&error];
  NSAssert(error == nil, @"Failed to get BuildAction node: %@", [error localizedFailureReason]);
  NSAssert([buildActionNodes count] == 1, @"Should have only one BuildAction node");
  NSXMLElement *buildActionNode = buildActionNodes[0];

  _parallelizeBuildables =
    [[[buildActionNode attributeForName:@"parallelizeBuildables"] stringValue] isEqualToString:@"YES"];
  _buildImplicitDependencies =
    [[[buildActionNode attributeForName:@"buildImplicitDependencies"] stringValue] isEqualToString:@"YES"];
}

- (void)loadSubjectInfo
{
  NSAssert(_subjectXcodeBuildArguments, @"Subject xcode build arguments should be defined.");
  NSAssert(_subjectScheme, @"Subject scheme should be defined.");
  NSAssert(_subjectWorkspace || _subjectProject, @"Subject workspace or project should be defined.");

  // First we need to know the OBJROOT and SYMROOT settings for the project we're testing.
  NSDictionary *settings = [self buildSettingsForATarget];
  NSDictionary *targetSettings = [settings allValues][0];

  _environmentForScripts = [targetSettings copy];

  // The following control where our build output goes - we need to make sure we build the tests
  // in the same places as we built the original products - this is what Xcode does.
  _objRoot = targetSettings[Xcode_OBJROOT];
  _symRoot = targetSettings[Xcode_SYMROOT];
  _sharedPrecompsDir = targetSettings[Xcode_SHARED_PRECOMPS_DIR];
  _effectivePlatformName = targetSettings[Xcode_EFFECTIVE_PLATFORM_NAME];
  _targetedDeviceFamily = targetSettings[Xcode_TARGETED_DEVICE_FAMILY];

  NSString *matchingSchemePath = nil;

  if (_subjectWorkspace) {
    matchingSchemePath = [self matchingSchemePathForWorkspace];
  } else {
    matchingSchemePath = [self matchingSchemePathForProject];
  }

  NSError *error = nil;
  _actionScripts = [[ActionScripts alloc] initWithSchemePath:matchingSchemePath
                                                 environment:_environmentForScripts
                                                       error:&error];
  NSAssert(!error, @"Error parsing Action Scripts: %@", error);

  if (_subjectWorkspace) {
    [self populateBuildablesAndTestablesForWorkspaceWithSchemePath:matchingSchemePath];
  } else {
    [self populateBuildablesAndTestablesForProjectWithSchemePath:matchingSchemePath];
  }

  [self populateBuildActionPropertiesWithSchemePath:matchingSchemePath];

  _configurationNameByAction =
    BuildConfigurationsByActionForSchemePath(matchingSchemePath);
}

- (Testable *)testableWithTarget:(NSString *)target
{
  for (Testable *testable in _testables) {
    if ([testable.target isEqualToString:target]) {
      return testable;
    }
  }
  return nil;
}

- (NSArray *)testablesAndBuildablesForTest
{
  NSMutableSet *targetsAdded = [NSMutableSet set];
  NSMutableArray *result = [NSMutableArray array];

  [_buildablesForTest enumerateObjectsUsingBlock:^(Buildable *item, NSUInteger idx, BOOL *stop) {
    if (![targetsAdded containsObject:item.target]) {
      [targetsAdded addObject:item.target];
      [result addObject:item];
    }
  }];

  [_testables enumerateObjectsUsingBlock:^(Testable *item, NSUInteger idx, BOOL *stop) {
    if (![targetsAdded containsObject:item.target]) {
      [targetsAdded addObject:item.target];
      [result addObject:item];
    }
  }];

  return result;
}

- (NSString *)configurationNameForAction:(NSString *)action
{
  return _configurationNameByAction[action];
}

@end
