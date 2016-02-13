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

#import "BuildTestsAction.h"

#import "Buildable.h"
#import "Options.h"
#import "SchemeGenerator.h"
#import "TaskUtil.h"
#import "Testable.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"
#import "XcodeSubjectInfo.h"

@implementation BuildTestsAction

+ (NSString *)name
{
  return @"build-tests";
}

+ (NSArray *)options
{
  return @[
    [Action actionOptionWithName:@"only"
                         aliases:nil
                     description:@"build only a specific test TARGET"
                       paramName:@"TARGET"
                           mapTo:@selector(addOnly:)],
    [Action actionOptionWithName:@"omit"
                         aliases:nil
                     description:@"omit building a specific test TARGET"
                       paramName:@"TARGET"
                           mapTo:@selector(addOmit:)],
    [Action actionOptionWithName:@"skip-deps"
                         aliases:nil
                     description:@"Only build the target, not its dependencies"
                         setFlag:@selector(setSkipDependencies:)],
  ];
}

+ (BOOL)buildWorkspace:(NSString *)path
                scheme:(NSString *)scheme
             reporters:(NSArray *)reporters
               objRoot:(NSString *)objRoot
               symRoot:(NSString *)symRoot
     sharedPrecompsDir:(NSString *)sharedPrecompsDir
       derivedDataPath:(NSString *)derivedDataPath
        xcodeArguments:(NSArray *)xcodeArguments
          xcodeCommand:(NSString *)xcodeCommand
{
  NSString *customDerivedDataLocation = derivedDataPath ?: [TemporaryDirectoryForAction() stringByAppendingPathComponent:@"DerivedData"];
  NSArray *taskArguments =
  [xcodeArguments arrayByAddingObjectsFromArray:@[
   @"-workspace", path,
   @"-scheme", scheme,
   // By setting these values to match the subject workspace/scheme
   // or project/scheme we're testing, we can reuse the already built
   // products.  Without this, xcodebuild would default to using the
   // generated workspace's DerivedData (which is empty, so everything
   // would get rebuilt).
   [NSString stringWithFormat:@"%@=%@", Xcode_OBJROOT, objRoot],
   [NSString stringWithFormat:@"%@=%@", Xcode_SYMROOT, symRoot],
   [NSString stringWithFormat:@"%@=%@", Xcode_SHARED_PRECOMPS_DIR, sharedPrecompsDir],
   // Override the DerivedData location to be within our temporary directory so
   // we don't accumulate junk in the user's real DerivedData folder.
   //
   // We're generating a new workspace and scheme every time we build
   // or run tests, and so xcodebuild wants to create a directory like
   // 'Tests-dgtnwkoyuhjfcibwyjiprineykfj' in DerivedData for every run.  Since
   // we're overriding OBJROOT/SYMROOM/SHARED_PRECOMPS_DIR, no build output ends
   // up here so the directory serves no purpose.  It's empty except for one
   // 'info.plist' file.
   [@"-IDECustomDerivedDataLocation=" stringByAppendingString:customDerivedDataLocation],
   xcodeCommand,
   ]];

  return RunXcodebuildAndFeedEventsToReporters(taskArguments,
                                               @"build",
                                               xcodeCommand,
                                               reporters);
}

+ (BOOL)buildTestables:(NSArray *)testables
               command:(NSString *)command
               options:(Options *)options
      xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  SchemeGenerator *schemeGenerator = [SchemeGenerator schemeGenerator];
  schemeGenerator.parallelizeBuildables = xcodeSubjectInfo.parallelizeBuildables;
  schemeGenerator.buildImplicitDependencies = xcodeSubjectInfo.buildImplicitDependencies;

  // For Xcode's Find Implicit Dependencies to work, we must add every project
  // in the subject's workspace to the generated workspace.
  if (options.workspace) {
    NSArray *projectPaths = [XcodeSubjectInfo projectPathsInWorkspace:options.workspace];
    for (NSString *projectPath in projectPaths) {
      [schemeGenerator addProjectPathToWorkspace:projectPath];
    }
  } else if (options.project) {
    [schemeGenerator addProjectPathToWorkspace:options.project];
  } else {
    NSAssert(NO, @"Should have a workspace or a project.");
  }

  for (Testable *testable in testables) {
    [schemeGenerator addBuildableWithID:testable.targetID inProject:testable.projectPath];
  }

  [xcodeSubjectInfo.actionScripts preBuildWithOptions:options];

  NSArray *xcodebuildArguments = [options commonXcodeBuildArgumentsForSchemeAction:@"TestAction"
                                                                  xcodeSubjectInfo:xcodeSubjectInfo];
  BOOL succeeded = [BuildTestsAction buildWorkspace:[schemeGenerator writeWorkspaceNamed:@"Tests"]
                                             scheme:@"Tests"
                                          reporters:options.reporters
                                            objRoot:xcodeSubjectInfo.objRoot
                                            symRoot:xcodeSubjectInfo.symRoot
                                  sharedPrecompsDir:xcodeSubjectInfo.sharedPrecompsDir
                                    derivedDataPath:options.derivedDataPath
                                     xcodeArguments:xcodebuildArguments
                                       xcodeCommand:command];

  [xcodeSubjectInfo.actionScripts postBuildWithOptions:options];

  if (!succeeded) {
    return NO;
  }
  return YES;
}

- (instancetype)init
{
  if (self = [super init]) {
    _onlyList = [[NSMutableArray alloc] init];
    _omitList = [[NSMutableArray alloc] init];
  }
  return self;
}


- (void)addOnly:(NSString *)argument
{
  [_onlyList addObject:argument];
}

- (void)addOmit:(NSString *)argument
{
  [_omitList addObject:argument];
}

- (BOOL)validateWithOptions:(Options *)options
           xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
               errorMessage:(NSString **)errorMessage
{
  if (_onlyList.count > 0 && _omitList.count > 0) {
    *errorMessage = @"build-tests: -only and -omit cannot both be specified.";
    return NO;
  }
  for (NSString *target in _onlyList) {
    if ([xcodeSubjectInfo testableWithTarget:target] == nil) {
      *errorMessage = [NSString stringWithFormat:@"build-tests: '%@' is not a testing target in this scheme.", target];
      return NO;
    }
  }

  return YES;
}

- (NSMutableArray *)buildableList:(NSArray *)buildableList
                  matchingTargets:(NSArray *)onlyList
                 excludingTargets:(NSArray *)omitList
{
  NSMutableArray *result = [NSMutableArray array];

  for (Buildable *buildable in buildableList) {
    BOOL add;
    if (onlyList.count > 0 && [[buildable.executable pathExtension] isEqualToString:@"octest"]) {
      // If we're filtering by target, only add targets that match.
      add = [onlyList containsObject:buildable.target];
    } else if (_skipDependencies) {
      add = NO;
    } else {
      add = !([buildable isKindOfClass:[Testable class]] &&
              ([(Testable *)buildable skipped] ||
               [omitList containsObject:buildable.target]));
    }
    if (add) {
      [result addObject:buildable];
    }
  }

  return result;
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  NSArray *buildableList = [self buildableList:[xcodeSubjectInfo testablesAndBuildablesForTest]
                               matchingTargets:_onlyList
                              excludingTargets:_omitList];
  if (!buildableList.count) {
    return YES;
  }

  return [BuildTestsAction buildTestables:buildableList
                                  command:@"build"
                                  options:options
                         xcodeSubjectInfo:xcodeSubjectInfo];
}

@end
