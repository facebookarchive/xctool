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

#import "TestAction.h"
#import "TestActionInternal.h"

#import "BuildTestsAction.h"
#import "RunTestsAction.h"

@interface TestAction ()

@property (nonatomic, retain) BuildTestsAction *buildTestsAction;
@property (nonatomic, retain) RunTestsAction *runTestsAction;

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
                     description:@"SPEC is TARGET[:Class/case[,Class2/case2]]"
                       paramName:@"SPEC"
                           mapTo:@selector(addOnly:)],
    [Action actionOptionWithName:@"skip-deps"
                         aliases:nil
                     description:@"Only build the target, not its dependencies"
                         setFlag:@selector(setSkipDependencies:)],
    [Action actionOptionWithName:@"freshSimulator"
                         aliases:nil
                     description:
     @"Start fresh simulator for each application test target"
                         setFlag:@selector(setFreshSimulator:)],
    [Action actionOptionWithName:@"freshInstall"
                         aliases:nil
                     description:
     @"Use clean install of TEST_HOST for every app test run"
                         setFlag:@selector(setFreshInstall:)],
    [Action actionOptionWithName:@"parallelize"
                         aliases:nil
                     description:@"Parallelize execution of tests"
                         setFlag:@selector(setParallelize:)],
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
    [Action actionOptionWithName:@"simulator"
                         aliases:nil
                     description:@"Set simulator type (either iphone or ipad)"
                       paramName:@"SIMULATOR"
                           mapTo:@selector(setSimulatorType:)],
    ];
}

- (id)init
{
  if (self = [super init]) {
    _buildTestsAction = [[BuildTestsAction alloc] init];
    _runTestsAction = [[RunTestsAction alloc] init];
  }
  return self;
}

- (void)dealloc {
  self.buildTestsAction = nil;
  self.runTestsAction = nil;
  [super dealloc];
}

- (void)setTestSDK:(NSString *)testSDK
{
  _runTestsAction.testSDK = testSDK;
}

- (void)setFreshSimulator:(BOOL)freshSimulator
{
  [_runTestsAction setFreshSimulator:freshSimulator];
}

- (void)setFreshInstall:(BOOL)freshInstall
{
  [_runTestsAction setFreshInstall:freshInstall];
}

- (void)setParallelize:(BOOL)parallelize
{
  [_runTestsAction setParallelize:parallelize];
}

- (void)setLogicTestBucketSize:(NSString *)bucketSize
{
  [_runTestsAction setLogicTestBucketSize:bucketSize];
}

- (void)setAppTestBucketSize:(NSString *)bucketSize
{
  [_runTestsAction setAppTestBucketSize:bucketSize];
}

- (void)setBucketBy:(NSString *)str
{
  [_runTestsAction setBucketBy:str];
}

- (void)setSimulatorType:(NSString *)simulatorType
{
  [_runTestsAction setSimulatorType:simulatorType];
}

- (void)setSkipDependencies:(BOOL)skipDependencies
{
  _buildTestsAction.skipDependencies = skipDependencies;
}

- (void)addOnly:(NSString *)argument
{
  // build-tests takes only a target argument, where run-tests takes Target:Class/method.
  NSString *buildTestsOnlyArg = [[argument componentsSeparatedByString:@":"] objectAtIndex:0];
  [_buildTestsAction.onlyList addObject:buildTestsOnlyArg];
  [_runTestsAction.onlyList addObject:argument];
}

- (NSArray *)onlyList
{
  return _buildTestsAction.onlyList;
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
