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

#import "BuildTestsAction.h"

#import "Options.h"
#import "Reporter.h"
#import "SchemeGenerator.h"
#import "TaskUtil.h"
#import "XcodeSubjectInfo.h"
#import "XCToolUtil.h"

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
        xcodeArguments:(NSArray *)xcodeArguments
          xcodeCommand:(NSString *)xcodeCommand
{
  NSArray *taskArguments = [xcodeArguments arrayByAddingObjectsFromArray:@[
                            @"-workspace", path,
                            @"-scheme", scheme,
                            [NSString stringWithFormat:@"OBJROOT=%@", objRoot],
                            [NSString stringWithFormat:@"SYMROOT=%@", symRoot],
                            [NSString stringWithFormat:@"SHARED_PRECOMPS_DIR=%@", sharedPrecompsDir],
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
  for (NSDictionary *buildable in testables) {
    [schemeGenerator addBuildableWithID:buildable[@"targetID"] inProject:buildable[@"projectPath"]];
  }

  BOOL succeeded = [BuildTestsAction buildWorkspace:[schemeGenerator writeWorkspaceNamed:@"Tests"]
                                             scheme:@"Tests"
                                          reporters:options.reporters
                                            objRoot:xcodeSubjectInfo.objRoot
                                            symRoot:xcodeSubjectInfo.symRoot
                                  sharedPrecompsDir:xcodeSubjectInfo.sharedPrecompsDir
                                     xcodeArguments:[options commonXcodeBuildArguments]
                                       xcodeCommand:command];
  [schemeGenerator cleanupTemporaryDirectories];

  if (!succeeded) {
    return NO;
  }
  return YES;
}

- (id)init
{
  if (self = [super init]) {
    self.onlyList = [NSMutableArray array];
  }
  return self;
}

- (void)dealloc {
  self.onlyList = nil;
  [super dealloc];
}

- (void)addOnly:(NSString *)argument
{
  [self.onlyList addObject:argument];
}

- (BOOL)validateOptions:(NSString **)errorMessage
          xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
         options:(Options *)options
{
  for (NSString *target in self.onlyList) {
    if ([xcodeSubjectInfo testableWithTarget:target] == nil) {
      *errorMessage = [NSString stringWithFormat:@"build-tests: '%@' is not a testing target in this scheme.", target];
      return NO;
    }
  }

  return YES;
}

- (NSMutableArray *)buildableList:(NSArray *)buildableList
                  matchingTargets:(NSArray *)targets
{
  NSMutableArray *result = [NSMutableArray array];

  for (NSDictionary *buildable in buildableList) {
    BOOL add;
    if (targets.count > 0 && [[buildable[@"executable"] pathExtension] isEqualToString:@"octest"]) {
      // If we're filtering by target, only add targets that match.
      add = [targets containsObject:buildable[@"target"]];
    } else if (_skipDependencies) {
      add = NO;
    } else {
      add = ![buildable[@"skipped"] boolValue];
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
                               matchingTargets:self.onlyList];

  if (![BuildTestsAction buildTestables:buildableList
                                command:@"build"
                                options:options
                       xcodeSubjectInfo:xcodeSubjectInfo]) {
    return NO;
  }

  return YES;
}

@end
