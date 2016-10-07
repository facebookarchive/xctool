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

#import "AnalyzeAction.h"

#import "BuildStateParser.h"
#import "Buildable.h"
#import "DgphFile.h"
#import "EventGenerator.h"
#import "EventSink.h"
#import "Options.h"
#import "ReporterEvents.h"
#import "XCToolUtil.h"
#import "XcodeSubjectInfo.h"

#include <regex>


@interface BuildTargetsCollector : NSObject <EventSink>
/// Array of @{@"projectName": projectName, @"targetName": targetName}
@property (nonatomic, strong) NSMutableSet *seenTargets;
@end

@implementation BuildTargetsCollector

- (instancetype)init
{
  if (self = [super init]) {
    _seenTargets = [[NSMutableSet alloc] init];
  }
  return self;
}


- (void)publishDataForEvent:(NSData *)data
{
  NSError *error = nil;
  NSDictionary *event = [NSJSONSerialization JSONObjectWithData:data
                                                        options:0
                                                          error:&error];
  NSAssert(event != nil, @"Error decoding JSON: %@", [error localizedFailureReason]);

  if ([event[kReporter_Event_Key] isEqualTo:kReporter_Events_BeginBuildTarget]) {
    [_seenTargets addObject:@{
     @"projectName": event[kReporter_BeginBuildTarget_ProjectKey],
     @"targetName": event[kReporter_BeginBuildTarget_TargetKey],
     }];
  }
}

@end

@interface AnalyzeAction ()
@property (nonatomic, strong) NSMutableSet *onlySet;
@property (nonatomic, assign) BOOL skipDependencies;
@property (nonatomic, assign) BOOL failOnWarnings;
@end

@implementation AnalyzeAction

+ (NSString *)name
{
  return @"analyze";
}

+ (NSArray *)options
{
  return @[[Action actionOptionWithName:@"only"
                                aliases:nil
                            description:
            @"only analyze selected targets, can be used more than once.\n"
            "\tIf this option is specified, its dependencies are assumed to be built."
                              paramName:@"TARGET"
                                  mapTo:@selector(addOnlyOption:)
            ],
           [Action actionOptionWithName:@"skip-deps"
                                aliases:nil
                            description:@"Skip initial build of the scheme"
                                setFlag:@selector(setSkipDependencies:)],
           [Action actionOptionWithName:@"failOnWarnings"
                                aliases:nil
                            description:@"Fail builds if analyzer warnings are found"
                                setFlag:@selector(setFailOnWarnings:)],
           ];
}

/*! Retrieve the location of the intermediate directory
 */
+ (NSString *)intermediatesDirForProject:(NSString *)projectName
                                  target:(NSString *)targetName
                           configuration:(NSString *)configuration
                                platform:(NSString *)platform
                                 objroot:(NSString *)objroot
{
  return [NSString pathWithComponents:@[
          objroot,
          [projectName stringByAppendingPathExtension:@"build"],
          [NSString stringWithFormat:@"%@%@", configuration, platform ?: @""],
          [targetName stringByAppendingPathExtension:@"build"],
          ]];
}

/*! Normalize the "path" of the diagnostic.

 @return NSArray of path elements, each of whic are dictionaries in the form:
          { "file": string,
            "line": int,
            "col": int,
            "message"  : string
          }
 */
+ (NSArray *)contextFromDiagPath:(NSArray *)path fileMap:(NSArray *)files
{
  NSMutableArray *result = [NSMutableArray array];
  for (NSDictionary *piece in path) {
    if ([piece[@"kind"] isEqual:kReporter_Event_Key]) {
      NSDictionary *location = piece[@"location"];
      [result addObject:@{@"file" : files[[location[@"file"] intValue]],
                          @"line" : location[@"line"],
                          @"col" : location[@"col"],
                          @"message" : piece[@"message"]}];
    }
  }
  return result;
}

+ (NSSet *)findAnalyzerPlistPathsForProject:(NSString *)projectName
                                     target:(NSString *)targetName
                                    options:(Options *)options
                           xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{

  static NSRegularExpression *analyzerPlistPathRegex =
    [NSRegularExpression regularExpressionWithPattern:@"^.*/StaticAnalyzer/.*\\.plist$"
                                              options:0
                                                error:0];

  // Used for dgph path.
  static const std::regex plistPathRegex("^.*/StaticAnalyzer/.*\\.plist");

  NSString *path = [[self class] intermediatesDirForProject:projectName
                                                     target:targetName
                                              configuration:[options effectiveConfigurationForSchemeAction:@"AnalyzeAction"
                                                                                          xcodeSubjectInfo:xcodeSubjectInfo]
                                                   platform:xcodeSubjectInfo.effectivePlatformName
                                                    objroot:xcodeSubjectInfo.objRoot];
  NSString *buildStatePath = [path stringByAppendingPathComponent:@"build-state.dat"];
  NSMutableSet *plistPaths = [NSMutableSet new];
  BOOL buildPathExists = [[NSFileManager defaultManager] fileExistsAtPath:buildStatePath];

  if (buildPathExists) {
    BuildStateParser *buildState = [[BuildStateParser alloc] initWithPath:buildStatePath];
    for (NSString *path in buildState.nodes) {
      NSTextCheckingResult *result = [analyzerPlistPathRegex
                                      firstMatchInString:path
                                      options:0
                                      range:NSMakeRange(0, path.length)];

      if (result == nil || result.range.location == NSNotFound) {
        continue;
      }

      [plistPaths addObject:path];
    }
    return plistPaths;
  }

  NSString *dgphPath = [path stringByAppendingPathComponent:@"dgph"];
  if ([[NSFileManager defaultManager] fileExistsAtPath:dgphPath]) {
    DgphFile dgph = DgphFile::loadFromFile(dgphPath.UTF8String);
    if (dgph.isValid()) {
      for (auto &invocation : dgph.getInvocations()) {
        for (auto &arg : invocation) {
          if (std::regex_match(arg, plistPathRegex)) {
            [plistPaths addObject:[NSString stringWithUTF8String:arg.c_str()]];
          }
        }
      }
    } else {
      NSLog(@"Failed to load dgph file to discover analyzer outputs, analyzer output may be incomplete.");
    }
  }

  if (path && projectName && targetName) {
    NSString *analyzerFilesPath = [NSString pathWithComponents:@[
                                                                 path,
                                                                 @"StaticAnalyzer",
                                                                 projectName,
                                                                 targetName,
                                                                 @"normal",
                                                                 options.arch ? options.arch : @"armv7",
                                                                 ]];

    NSArray *pathContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:analyzerFilesPath error:nil];

    for (NSString *path in pathContents) {
      if ([[path pathExtension] isEqualToString:@"plist"]) {
        NSString *plistPath = [NSString pathWithComponents:@[analyzerFilesPath, path]];
        [plistPaths addObject:plistPath];
      }
    }
    return plistPaths;
  }

  NSLog(@"No build-state.dat for project/target: %@/%@, skipping...\n"
        "  it may be overriding CONFIGURATION_TEMP_DIR and emitting intermediate \n"
        "  files in a non-standard location", projectName, targetName);
  return plistPaths;
}

+ (void)emitAnalyzerWarningsForProject:(NSString *)projectName
                                target:(NSString *)targetName
                            plistPaths:(NSSet *)plistPaths
                           toReporters:(NSArray *)reporters
                         foundWarnings:(BOOL *)foundWarnings
{

  BOOL haveFoundWarnings = NO;

  NSFileManager *fileManager = [NSFileManager defaultManager];
  for (NSString *path in plistPaths) {
    NSDictionary *diags = [NSDictionary dictionaryWithContentsOfFile:path];
    if (!diags) {
      continue;
    }
    for (NSDictionary *diag in diags[@"diagnostics"]) {
      haveFoundWarnings = YES;
      NSString *file = diags[@"files"][[diag[@"location"][@"file"] intValue]];
      file = file.stringByStandardizingPath;
      if (![fileManager fileExistsAtPath:file]) {
        continue;
      }
      NSNumber *line = diag[@"location"][@"line"];
      NSNumber *col = diag[@"location"][@"col"];
      NSString *desc = diag[@"description"];
      NSString *category = diag[@"category"];
      NSString *type = diag[@"type"];
      NSArray *context = [self.class contextFromDiagPath:diag[@"path"]
                                                 fileMap:diags[@"files"]];

      PublishEventToReporters(reporters,
        EventDictionaryWithNameAndContent(kReporter_Events_AnalyzerResult, @{
          kReporter_AnalyzerResult_ProjectKey: projectName,
          kReporter_AnalyzerResult_TargetKey: targetName,
          kReporter_AnalyzerResult_FileKey: file,
          kReporter_AnalyzerResult_LineKey: line,
          kReporter_AnalyzerResult_ColumnKey: col,
          kReporter_AnalyzerResult_DescriptionKey: desc,
          kReporter_AnalyzerResult_ContextKey: context,
          kReporter_AnalyzerResult_CategoryKey: category,
          kReporter_AnalyzerResult_TypeKey: type,
          }));
    }
  }

  if (foundWarnings) {
    *foundWarnings = haveFoundWarnings;
  }
}

- (instancetype)init
{
  if (self = [super init]) {
    _onlySet = [[NSMutableSet alloc] init];
  }
  return self;
}


- (void)addOnlyOption:(NSString *)targetName
{
  [_onlySet addObject:targetName];
}

- (BOOL)performActionWithOptions:(Options *)options
                xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  [xcodeSubjectInfo.actionScripts preAnalyzeWithOptions:options];

  BuildTargetsCollector *buildTargetsCollector = [[BuildTargetsCollector alloc] init];
  NSArray *reporters = [options.reporters arrayByAddingObject:buildTargetsCollector];

  NSArray *buildArgs = [[options xcodeBuildArgumentsForSubject]
                        arrayByAddingObjectsFromArray:
                        [options commonXcodeBuildArgumentsForSchemeAction:@"AnalyzeAction"
                                                         xcodeSubjectInfo:xcodeSubjectInfo]];

  BOOL success = YES;
  if (_onlySet.count) {
    if (!_skipDependencies) {
      // build everything, and then build with analyze only the specified buildables
      NSArray *args = [buildArgs arrayByAddingObject:@"build"];
      success = RunXcodebuildAndFeedEventsToReporters(args, @"build", [options scheme], reporters);
    }

    if (success) {
      for (Buildable *buildable in xcodeSubjectInfo.buildables) {
        if (!buildable.buildForAnalyzing ||
            ![_onlySet containsObject:buildable.target]) {
          continue;
        }
        NSArray *args =
        [[options commonXcodeBuildArgumentsForSchemeAction:@"AnalyzeAction"
                                          xcodeSubjectInfo:xcodeSubjectInfo]
         arrayByAddingObjectsFromArray:@[
         @"-project", buildable.projectPath,
         @"-target", buildable.target,
         @"analyze",
         [NSString stringWithFormat:@"OBJROOT=%@", xcodeSubjectInfo.objRoot],
         [NSString stringWithFormat:@"SYMROOT=%@", xcodeSubjectInfo.symRoot],
         [NSString stringWithFormat:@"SHARED_PRECOMPS_DIR=%@", xcodeSubjectInfo.sharedPrecompsDir],
         ]];
        success &= RunXcodebuildAndFeedEventsToReporters(args, @"analyze", [options scheme], reporters);
      }
    }
  } else {
    NSArray *args = [buildArgs arrayByAddingObjectsFromArray:@[
                     @"analyze"]];
    success = RunXcodebuildAndFeedEventsToReporters(args, @"analyze", [options scheme], reporters);
  }

  [xcodeSubjectInfo.actionScripts postAnalyzeWithOptions:options];

  if (!success) {
    return NO;
  }

  BOOL haveFoundWarnings = NO;

  for (NSDictionary *buildable in buildTargetsCollector.seenTargets) {
    if (_onlySet.count && ![_onlySet containsObject:buildable[@"targetName"]]) {
      continue;
    }

    BOOL foundWarningsInBuildable = NO;
    NSSet *plistPaths = [self.class findAnalyzerPlistPathsForProject:buildable[@"projectName"]
                                                              target:buildable[@"targetName"]
                                                             options:options
                                                    xcodeSubjectInfo:xcodeSubjectInfo];
    [self.class emitAnalyzerWarningsForProject:buildable[@"projectName"]
                                        target:buildable[@"targetName"]
                                    plistPaths:plistPaths
                                   toReporters:options.reporters
                                 foundWarnings:&foundWarningsInBuildable];
    haveFoundWarnings |= foundWarningsInBuildable;
  }

  if (_failOnWarnings) {
    return !haveFoundWarnings;
  } else {
    return YES;
  }
}

@end
