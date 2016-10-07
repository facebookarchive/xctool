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

#import "TestAction.h"
#import "TestActionInternal.h"

#import "BuildTestsAction.h"
#import "Options.h"
#import "RunTestsAction.h"
#import "XCToolUtil.h"

@interface TestAction ()

@property (nonatomic, strong) BuildTestsAction *buildTestsAction;
@property (nonatomic, strong) RunTestsAction *runTestsAction;

@end

@implementation TestAction

+ (NSString *)name
{
  return @"test";
}

+ (NSArray *)options
{
  return
  @[
    [Action actionOptionWithName:@"test-sdk"
                         aliases:nil
                     description:@"SDK to test with"
                       paramName:@"SDK"
                           mapTo:@selector(setTestSDK:)],
    [Action actionOptionWithName:@"only"
                         aliases:nil
                     description:
     @"SPEC is TARGET[:Class/case[,Class2/case2]]; use * when specifying class or case prefix."
                       paramName:@"SPEC"
                           mapTo:@selector(addOnly:)],
    [Action actionOptionWithName:@"omit"
                         aliases:nil
                     description:
     @"SPEC is TARGET[:Class/case[,Class2/case2]]; use * when specifying class or case prefix."
                       paramName:@"SPEC"
                           mapTo:@selector(addOmit:)],
    [Action actionOptionWithName:@"skip-deps"
                         aliases:nil
                     description:@"Only build the target, not its dependencies"
                         setFlag:@selector(setSkipDependencies:)],
    [Action actionOptionWithName:@"freshSimulator"
                         aliases:nil
                     description:
     @"Start fresh simulator for each application test target"
                         setFlag:@selector(setFreshSimulator:)],
    [Action actionOptionWithName:@"resetSimulator"
                         aliases:nil
                     description:
     @"Reset simulator content and settings and restart it before running every app test run."
                         setFlag:@selector(setResetSimulator:)],
    [Action actionOptionWithName:@"newSimulatorInstance"
                         aliases:nil
                     description:
     @"Create new simulator instance for each application test target"
                         setFlag:@selector(setNewSimulatorInstance:)],
    [Action actionOptionWithName:@"noResetSimulatorOnFailure"
                         aliases:nil
                     description:
     @"Do not reset simulator content and settings if running failed."
                         setFlag:@selector(setNoResetSimulatorOnFailure:)],
    [Action actionOptionWithName:@"freshInstall"
                         aliases:nil
                     description:
     @"Use clean install of TEST_HOST for every app test run"
                         setFlag:@selector(setFreshInstall:)],
    [Action actionOptionWithName:@"parallelize"
                         aliases:nil
                     description:@"Parallelize execution of tests"
                         setFlag:@selector(setParallelize:)],
    [Action actionOptionWithName:@"failOnEmptyTestBundles"
                         aliases:nil
                     description:@"Fail when an empty test bundle was run."
                         setFlag:@selector(setFailOnEmptyTestBundles:)],
    [Action actionOptionWithName:@"logicTestBucketSize"
                         aliases:nil
                     description:@"Break logic test bundles in buckets of N test cases."
                       paramName:@"N"
                           mapTo:@selector(setLogicTestBucketSize:)],
    [Action actionOptionWithName:@"appTestBucketSize"
                         aliases:nil
                     description:@"Break app test bundles in buckets of N test cases."
                       paramName:@"N"
                           mapTo:@selector(setAppTestBucketSize:)],
    [Action actionOptionWithName:@"bucketBy"
                         aliases:nil
                     description:@"Either 'case' (default) or 'class'."
                       paramName:@"BUCKETBY"
                           mapTo:@selector(setBucketBy:)],
    [Action actionOptionWithName:@"listTestsOnly"
                         aliases:nil
                     description:@"Skip actual test running and list them only."
                         setFlag:@selector(setListTestsOnly:)],
    [Action actionOptionWithName:@"waitForDebugger"
                         aliases:nil
                     description:@"Spawn tests but wait for debugger to attach."
                         setFlag:@selector(setWaitForDebugger:)],
    [Action actionOptionWithName:@"testTimeout"
                         aliases:nil
                     description:
     @"Force individual test cases to be killed after specified timeout."
                       paramName:@"N"
                           mapTo:@selector(setTestTimeout:)],
    ];
}

- (instancetype)init
{
  if (self = [super init]) {
    _buildTestsAction = [[BuildTestsAction alloc] init];
    _runTestsAction = [[RunTestsAction alloc] init];
  }
  return self;
}

- (void)setTestSDK:(NSString *)testSDK
{
  [_runTestsAction setTestSDK:testSDK];
}

- (void)setFreshSimulator:(BOOL)freshSimulator
{
  [_runTestsAction setFreshSimulator:freshSimulator];
}

- (void)setResetSimulator:(BOOL)resetSimulator
{
  [_runTestsAction setResetSimulator:resetSimulator];
}

- (void)setNewSimulatorInstance:(BOOL)newSimulatorInstance
{
  [_runTestsAction setNewSimulatorInstance:newSimulatorInstance];
}

- (void)setNoResetSimulatorOnFailure:(BOOL)noResetSimulatorOnFailure
{
  [_runTestsAction setNoResetSimulatorOnFailure:noResetSimulatorOnFailure];
}

- (void)setFreshInstall:(BOOL)freshInstall
{
  [_runTestsAction setFreshInstall:freshInstall];
}

- (void)setWaitForDebugger:(BOOL)waitForDebugger
{
  [_runTestsAction setWaitForDebugger:waitForDebugger];
}

- (void)setParallelize:(BOOL)parallelize
{
  [_runTestsAction setParallelize:parallelize];
}

- (void)setLogicTestBucketSize:(NSString *)bucketSize
{
  [_runTestsAction setLogicTestBucketSizeValue:bucketSize];
}

- (void)setAppTestBucketSize:(NSString *)bucketSize
{
  [_runTestsAction setAppTestBucketSizeValue:bucketSize];
}

- (void)setBucketBy:(NSString *)str
{
  [_runTestsAction setBucketByValue:str];
}

- (void)setSkipDependencies:(BOOL)skipDependencies
{
  _buildTestsAction.skipDependencies = skipDependencies;
}

- (void)setFailOnEmptyTestBundles:(BOOL)failOnEmptyTestBundles
{
  [_runTestsAction setFailOnEmptyTestBundles:failOnEmptyTestBundles];
}

- (void)setListTestsOnly:(BOOL)listTestsOnly
{
  [_runTestsAction setListTestsOnly:listTestsOnly];
}

- (void)setTestTimeout:(NSString *)testTimeout
{
  [_runTestsAction setTestTimeoutValue:testTimeout];
}

- (void)addOnly:(NSString *)argument
{
  // build-tests takes only a target argument, where run-tests takes Target:Class/method.
  NSString *buildTestsOnlyArg = [argument componentsSeparatedByString:@":"][0];
  [_buildTestsAction.onlyList addObject:buildTestsOnlyArg];
  [_runTestsAction.onlyList addObject:argument];
}

- (void)addOmit:(NSString *)argument
{
  // build-tests takes only a target argument, where run-tests takes Target:Class/method.
  NSString *buildTestsOmitArg = [argument componentsSeparatedByString:@":"][0];
  [_buildTestsAction.omitList addObject:buildTestsOmitArg];
  [_runTestsAction.omitList addObject:argument];
}

- (NSArray *)onlyList
{
  return _buildTestsAction.onlyList;
}

- (NSArray *)omitList
{
  return _buildTestsAction.omitList;
}

- (BOOL)skipDependencies
{
  return _buildTestsAction.skipDependencies;
}

- (BOOL)validateWithOptions:(Options *)options
           xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
               errorMessage:(NSString **)errorMessage
{
  if (![_buildTestsAction validateWithOptions:options
                             xcodeSubjectInfo:xcodeSubjectInfo
                                 errorMessage:errorMessage]) {
    return NO;
  }

  if (![_runTestsAction validateWithOptions:options
                           xcodeSubjectInfo:xcodeSubjectInfo
                               errorMessage:errorMessage]) {
    return NO;
  }

  return YES;
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  if (![_buildTestsAction performActionWithOptions:options xcodeSubjectInfo:xcodeSubjectInfo]) {
    return NO;
  }

  if (![_runTestsAction performActionWithOptions:options xcodeSubjectInfo:xcodeSubjectInfo]) {
    return NO;
  }

  return YES;
}

@end
