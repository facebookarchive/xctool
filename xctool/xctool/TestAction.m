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
    [Action actionOptionWithName:@"killSimulator"
                         aliases:nil
                     description:@"kill simulator before testing starts"
                         setFlag:@selector(setKillSimulator:)],
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

- (void)setKillSimulator:(BOOL)killSimulator
{
  _runTestsAction.killSimulator = killSimulator;
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

- (BOOL)validateOptions:(NSString **)errorMessage
       xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
                options:(Options *)options
{
  if (![_buildTestsAction validateOptions:errorMessage
                         xcodeSubjectInfo:xcodeSubjectInfo
                                  options:options]) {
    return NO;
  }

  if (![_runTestsAction validateOptions:errorMessage
                       xcodeSubjectInfo:xcodeSubjectInfo
                                options:options]) {
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

- (BOOL)validateSDK:(NSString *)sdk
{
  return [_buildTestsAction validateSDK:sdk] && [_runTestsAction validateSDK:sdk];
}

@end
