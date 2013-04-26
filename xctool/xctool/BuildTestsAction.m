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

+ (BOOL)buildTestable:(NSDictionary *)testable
            reporters:(NSArray *)reporters
              objRoot:(NSString *)objRoot
              symRoot:(NSString *)symRoot
    sharedPrecompsDir:(NSString *)sharedPrecompsDir
       xcodeArguments:(NSArray *)xcodeArguments
         xcodeCommand:(NSString *)xcodeCommand
{
  NSString *testableProjectPath = testable[@"projectPath"];
  NSString *testableTarget = testable[@"target"];

  NSArray *taskArguments = [xcodeArguments arrayByAddingObjectsFromArray:@[
                            @"-project", testableProjectPath,
                            @"-target", testableTarget,
                            [NSString stringWithFormat:@"OBJROOT=%@", objRoot],
                            [NSString stringWithFormat:@"SYMROOT=%@", symRoot],
                            [NSString stringWithFormat:@"SHARED_PRECOMPS_DIR=%@", sharedPrecompsDir],
                            xcodeCommand,
                            ]];

  // Build the test target.
  NSTask *buildTask = TaskInstance();
  [buildTask setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"]];
  [buildTask setArguments:taskArguments];
  NSMutableDictionary *environment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
  [environment addEntriesFromDictionary:@{
   @"DYLD_INSERT_LIBRARIES" : [PathToXCToolBinaries() stringByAppendingPathComponent:@"xcodebuild-shim.dylib"],
   @"PATH": @"/usr/bin:/bin:/usr/sbin:/sbin",
  }];
  [buildTask setEnvironment:environment];

  [reporters makeObjectsPerformSelector:@selector(handleEvent:)
                             withObject:@{
   @"event": kReporter_Events_BeginXcodebuild,
   kReporter_BeginXcodebuild_CommandKey: xcodeCommand,
   kReporter_BeginXcodebuild_TitleKey: testableTarget,
   }];

  LaunchTaskAndFeedOuputLinesToBlock(buildTask, ^(NSString *line){
    NSError *error = nil;
    NSDictionary *event = [NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding]
                                                          options:0
                                                            error:&error];
    NSCAssert(error == nil, @"Got error while trying to deserialize event '%@': %@", line, [error localizedFailureReason]);

    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:event];
  });

  [reporters makeObjectsPerformSelector:@selector(handleEvent:)
                             withObject:@{
   @"event": kReporter_Events_EndXcodebuild,
   kReporter_EndXcodebuild_CommandKey: xcodeCommand,
   kReporter_EndXcodebuild_TitleKey: testableTarget,
   }];

  return ([buildTask terminationStatus] == 0);
}

+ (BOOL)buildTestables:(NSArray *)testables
               command:(NSString *)command
               options:(Options *)options
      xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  for (NSDictionary *testable in testables) {
    BOOL succeeded = [self buildTestable:testable
                               reporters:options.reporters
                                 objRoot:xcodeSubjectInfo.objRoot
                                 symRoot:xcodeSubjectInfo.symRoot
                       sharedPrecompsDir:xcodeSubjectInfo.sharedPrecompsDir
                          xcodeArguments:[options commonXcodeBuildArguments]
                            xcodeCommand:command];
    if (!succeeded) {
      return NO;
    }
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
  NSMutableSet *targetsAdded = [NSMutableSet set];
  NSMutableArray *buildableList = [NSMutableArray array];

  [xcodeSubjectInfo.buildablesForTest enumerateObjectsUsingBlock:^(NSDictionary *item, NSUInteger idx, BOOL *stop) {
    NSString *target = item[@"target"];
    if (![targetsAdded containsObject:target]) {
      [targetsAdded addObject:target];
      [buildableList addObject:item];
    }
  }];

  [xcodeSubjectInfo.testables enumerateObjectsUsingBlock:^(NSDictionary *item, NSUInteger idx, BOOL *stop) {
    NSString *target = item[@"target"];
    if (![targetsAdded containsObject:target]) {
      [targetsAdded addObject:target];
      [buildableList addObject:item];
    }
  }];

  buildableList = [self buildableList:buildableList matchingTargets:self.onlyList];

  if (![BuildTestsAction buildTestables:buildableList
                          command:@"build"
                          options:options
                    xcodeSubjectInfo:xcodeSubjectInfo]) {
    return NO;
  }

  return YES;
}

@end
