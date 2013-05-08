//
// Copyright 2013 Facebook
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

#import "TaskUtil.h"
#import "XCToolUtil.h"
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
    } else {
      [stack addObject:component];
    }
  }
  return [stack componentsJoinedByString:@"/"];
}

static NSString *BasePathFromSchemePath(NSString *schemePath) {
  for (;;) {
    assert(schemePath.length > 0);

    if ([schemePath hasSuffix:@".xcodeproj"] || [schemePath hasSuffix:@".xcworkspace"]) {
      schemePath = [schemePath stringByDeletingLastPathComponent];
      break;
    }

    schemePath = [schemePath stringByDeletingLastPathComponent];
  }

  if (schemePath.length == 0) {
    schemePath = @".";
  }

  return schemePath;
}

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
  NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithContentsOfURL:URL
                                                             options:0
                                                               error:&error] autorelease];
  if (error != nil) {
    NSLog(@"Error in parsing: %@: %@", workspacePath, error);
    abort();
  }

  __block NSString *(^fullLocation)(NSXMLNode*, NSString *) = ^(NSXMLNode *node, NSString *containerPath) {

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
      return [fullLocation(node.parent, containerPath) stringByAppendingPathComponent:locationAfterColon];
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
  NSMutableArray *projectFiles = [NSMutableArray array];
  for (NSXMLElement *node in fileRefNodes) {
    NSString *location = [[node attributeForName:@"location"] stringValue];

    if ([location hasSuffix:@".xcodeproj"]) {
      [projectFiles addObject:StringByStandardizingPath(fullLocation(node, workspaceBasePath))];
    }
  }

  return projectFiles;
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
  NSString *userdataPath = [project stringByAppendingPathComponent:@"xcuserdata"];
  NSArray *userContents = [fm contentsOfDirectoryAtPath:userdataPath
                                                  error:nil];
  if (userContents != nil) {
    for (NSString *file in userContents) {
      if ([file hasSuffix:@".xcuserdatad"]) {
        NSString *userSchemesPath = [[userdataPath stringByAppendingPathComponent:file] stringByAppendingPathComponent:@"xcschemes"];
        NSArray *userSchemesContents = [fm contentsOfDirectoryAtPath:userSchemesPath error:nil];

        for (NSString *file in userSchemesContents) {
          if ([file hasSuffix:@".xcscheme"]) {
            [schemes addObject:[userSchemesPath stringByAppendingPathComponent:file]];
          }
        }
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
  NSString *result = [workspaceInfoPlist objectForKey:@"WorkspacePath"];

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
  NSString *derivedDataLocation = [xcodePrefs objectForKey:@"IDECustomDerivedDataLocation"] ?:
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
          [workspacePathModifyDates setObject:modifiedDate
                                       forKey:workspacePath];
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
          [workspacePathModifyDates setObject:modifiedDate
                                       forKey:workspacePath];
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
        [recentlyModifiedWorkspaces objectForKey:containerPath];

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

- (void)dealloc
{
  self.sdkName = nil;
  self.objRoot = nil;
  self.symRoot = nil;
  self.configuration = nil;
  self.testables = nil;
  self.buildablesForTest = nil;
  [super dealloc];
}

+ (BOOL)   findTarget:(NSString *)target
        inSchemePaths:(NSArray *)schemePaths
        targetMatches:(NSArray **)targetMatchesOut {
  BOOL found = NO;
  NSMutableArray *targetMatches = [NSMutableArray array];

  for (NSString *schemePath in schemePaths) {
    NSArray *testables = [self testablesInSchemePath:schemePath
                                            basePath:BasePathFromSchemePath(schemePath)];
    for (NSDictionary *testableDict in testables) {
      if ([[testableDict objectForKey:@"target"] isEqualToString:target]) {
        found = YES;
        XcodeTargetMatch *match = [[[XcodeTargetMatch alloc] init] autorelease];
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
  NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:schemePath]
                                                             options:0
                                                               error:&error] autorelease];
  if (error != nil) {
    NSLog(@"Error in parsing: %@: %@", schemePath, error);
    abort();
  }

  NSArray *buildActionEntryNodes = [doc nodesForXPath:@"//BuildActionEntry" error:nil];
  return [buildActionEntryNodes count];
}

+ (NSArray *)testablesInSchemePath:(NSString *)schemePath basePath:(NSString *)basePath
{
  NSError *error = nil;
  NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:schemePath]
                                                             options:0
                                                               error:&error] autorelease];
  if (error != nil) {
    NSLog(@"Error in parsing: %@: %@", schemePath, error);
    abort();
  }

  NSArray *testableReferenceNodes = [doc nodesForXPath:@"//TestableReference" error:nil];

  NSMutableArray *testables = [NSMutableArray array];
  for (NSXMLElement *node in testableReferenceNodes) {
    NSNumber *skipped =
      [[[node attributeForName:@"skipped"] stringValue] isEqualToString:@"YES"] ? @YES : @NO;
    NSArray *buildableReferences = [node nodesForXPath:@"BuildableReference" error:nil];

    assert(buildableReferences.count == 1);
    NSXMLElement *buildableReference = buildableReferences[0];

    NSString *referencedContainer = [[buildableReference attributeForName:@"ReferencedContainer"] stringValue];
    assert([referencedContainer hasPrefix:@"container:"]);

    NSString *projectPath = StringByStandardizingPath([basePath stringByAppendingPathComponent:[referencedContainer substringFromIndex:@"container:".length]]);
    if (![[NSFileManager defaultManager] fileExistsAtPath:projectPath]) {
      NSLog(@"Error: Scheme %@ base %@ contains reference to non-existent project: %@", schemePath, basePath,projectPath);
      abort();
    }

    NSString *executable = [[buildableReference attributeForName:@"BuildableName"] stringValue];
    NSString *target = [[buildableReference attributeForName:@"BlueprintName"] stringValue];

    NSArray *skippedTestsNodes = [node nodesForXPath:@"SkippedTests/Test" error:nil];
    NSMutableArray *testsToSkip = [NSMutableArray array];
    for (NSXMLElement *node in skippedTestsNodes) {
      NSString *test = [[node attributeForName:@"Identifier"] stringValue];
      [testsToSkip addObject:test];
    }

    NSString *senTestList = nil;
    BOOL senTestInvertScope = NO;
    if (testsToSkip.count > 0) {
      senTestList = [testsToSkip componentsJoinedByString:@","];
      senTestInvertScope = YES;
    } else {
      senTestList = @"All";
      senTestInvertScope = NO;
    }

    [testables addObject:@{@"projectPath" : projectPath, @"target": target, @"executable": executable, @"senTestInvertScope": @(senTestInvertScope), @"senTestList": senTestList, @"skipped": skipped}];
  }

  return testables;
}

+ (NSArray *)buildablesForTestInSchemePath:(NSString *)schemePath basePath:(NSString *)basePath
{
  NSError *error = nil;
  NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:schemePath]
                                                             options:0
                                                               error:&error] autorelease];
  if (error != nil) {
    NSLog(@"Error in parsing: %@: %@", schemePath, error);
    abort();
  }

  NSArray *buildActionEntryNodes = [doc nodesForXPath:@"//BuildActionEntry[@buildForTesting='YES']" error:nil];

  NSMutableArray *buildables = [NSMutableArray array];
  for (NSXMLElement *node in buildActionEntryNodes) {
    NSArray *buildableReferences = [node nodesForXPath:@"BuildableReference" error:nil];

    assert(buildableReferences.count == 1);
    NSXMLElement *buildableReference = buildableReferences[0];

    NSString *referencedContainer = [[buildableReference attributeForName:@"ReferencedContainer"] stringValue];
    assert([referencedContainer hasPrefix:@"container:"]);

    NSString *projectPath = StringByStandardizingPath([basePath stringByAppendingPathComponent:[referencedContainer substringFromIndex:@"container:".length]]);
    if (![[NSFileManager defaultManager] fileExistsAtPath:projectPath]) {
      NSLog(@"Error: Scheme %@ base %@ contains reference to non-existent project: %@", schemePath, basePath, projectPath);
      abort();
    }

    NSString *target = [[buildableReference attributeForName:@"BlueprintName"] stringValue];
    NSString *executable = [[buildableReference attributeForName:@"BuildableName"] stringValue];

    [buildables addObject:@{
     @"projectPath" : projectPath,
     @"target": target,
     @"executable":executable,
     }];
  }

  return buildables;
}

- (void)populate
{
  if (_didPopulate) {
    return;
  }

  assert(self.subjectXcodeBuildArguments != nil);
  assert(self.subjectScheme != nil);
  assert(self.subjectWorkspace != nil || self.subjectProject != nil);

  // First we need to know the OBJROOT and SYMROOT settings for the project we're testing.
  NSTask *task = TaskInstance();
  [task setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"]];
  [task setArguments:[self.subjectXcodeBuildArguments arrayByAddingObject:@"-showBuildSettings"]];
  [task setEnvironment:@{
   @"DYLD_INSERT_LIBRARIES" : [PathToXCToolBinaries() stringByAppendingPathComponent:@"xcodebuild-fastsettings-shim.dylib"],
   @"SHOW_ONLY_BUILD_SETTINGS_FOR_FIRST_BUILDABLE" : @"YES"
   }];

  NSDictionary *result = LaunchTaskAndCaptureOutput(task);
  NSDictionary *settings = BuildSettingsFromOutput(result[@"stdout"]);

  assert(settings.count == 1);
  NSDictionary *firstBuildable = [settings allValues][0];
  // The following control where our build output goes - we need to make sure we build the tests
  // in the same places as we built the original products - this is what Xcode does.
  self.objRoot = firstBuildable[@"OBJROOT"];
  self.symRoot = firstBuildable[@"SYMROOT"];
  self.sharedPrecompsDir = firstBuildable[@"SHARED_PRECOMPS_DIR"];
  self.sdkName = firstBuildable[@"SDK_NAME"];
  self.configuration = firstBuildable[@"CONFIGURATION"];

  if (self.subjectWorkspace) {
    NSString *matchingSchemePath = nil;
    NSArray *schemePaths = [XcodeSubjectInfo schemePathsInWorkspace:self.subjectWorkspace];
    for (NSString *schemePath in schemePaths) {
      if ([schemePath hasSuffix:[NSString stringWithFormat:@"/%@.xcscheme", self.subjectScheme]]) {
        matchingSchemePath = schemePath;
      }
    }

    NSSet *projectPathsInWorkspace = [NSSet setWithArray:[XcodeSubjectInfo projectPathsInWorkspace:self.subjectWorkspace]];

    NSArray *(^itemsMatchingProjectPath)(NSArray *) = ^(NSArray *items) {
      NSMutableArray *newItems = [NSMutableArray array];
      for (NSDictionary *item in items) {
        if ([projectPathsInWorkspace containsObject:item[@"projectPath"]]) {
          [newItems addObject:item];
        }
      }
      return newItems;
    };

    NSArray *testables = [[self class] testablesInSchemePath:matchingSchemePath
                                                    basePath:BasePathFromSchemePath(matchingSchemePath)];
    NSArray *buildablesForTest = [[self class] buildablesForTestInSchemePath:matchingSchemePath
                                                                    basePath:BasePathFromSchemePath(matchingSchemePath)];

    // It's possible that the scheme references projects that aren't part of the workspace.  When
    // Xcode encounters these, it just skips them so we'll do the same.
    self.testables = itemsMatchingProjectPath(testables);
    self.buildablesForTest = itemsMatchingProjectPath(buildablesForTest);
  } else {
    NSString *matchingSchemePath = nil;
    NSArray *schemePaths = [XcodeSubjectInfo schemePathsInContainer:self.subjectProject];
    for (NSString *schemePath in schemePaths) {
      if ([schemePath hasSuffix:[NSString stringWithFormat:@"/%@.xcscheme", self.subjectScheme]]) {
        matchingSchemePath = schemePath;
      }
    }

    self.testables = [[self class] testablesInSchemePath:matchingSchemePath
                                                basePath:BasePathFromSchemePath(matchingSchemePath)];
    self.buildablesForTest = [[self class] buildablesForTestInSchemePath:matchingSchemePath
                                                                basePath:BasePathFromSchemePath(matchingSchemePath)];
  }

  _didPopulate = YES;
}

- (NSDictionary *)testableWithTarget:(NSString *)target
{
  for (NSDictionary *testable in self.testables) {
    NSString *testableTarget = testable[@"target"];
    if ([testableTarget isEqualToString:target]) {
      return testable;
    }
  }
  return nil;
}

- (NSString *)sdkName
{
  [self populate];
  return _sdkName;
}

- (NSString *)objRoot
{
  [self populate];
  return _objRoot;
}

- (NSString *)symRoot
{
  [self populate];
  return _symRoot;
}

- (NSString *)configuration
{
  [self populate];
  return _configuration;
}

- (NSArray *)testables
{
  [self populate];
  return _testables;
}

- (NSArray *)buildablesForTest
{
  [self populate];
  return _buildablesForTest;
}

@end
