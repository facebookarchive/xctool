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

#import <Foundation/Foundation.h>

#import "SimulatorInfo.h"
#import "TestRunState.h"
#import "TestingFramework.h"

@interface OCUnitTestRunner : NSObject {
@protected
  NSDictionary *_buildSettings;
  SimulatorInfo *_simulatorInfo;
  NSArray *_focusedTestCases;
  NSArray *_allTestCases;
  NSArray *_arguments;
  NSDictionary *_environment;
  BOOL _garbageCollection;
  BOOL _freshSimulator;
  BOOL _resetSimulator;
  BOOL _newSimulatorInstance;
  BOOL _noResetSimulatorOnFailure;
  BOOL _freshInstall;
  NSInteger _testTimeout;
  NSArray *_reporters;
  NSDictionary *_framework;
}

@property (nonatomic, copy, readonly) NSArray *reporters;

/**
 * Filters a list of test cases by removing test cases with names matching
 * `skippedTestCases` constraints and, if set, all tests cases not matching
 * `onlyTestCases` ones.
 *
 * @param allTestCases An array of test cases ('ClassA/test1', 'ClassB/test2', 'Class')
 * @param onlyTestCases An array of test case name constraints defining what test
 *                      cases should only be included ('Class*', 'Class1', 'ClassA/test*', 'ClassB/test2')
 * @param skippedTestCases An array of test case name constraints defining what test 
 *                         cases should be removed ('Class*', 'Class1', 'ClassA/test*', 'ClassB/test2')
 * @param error An output parameter which is set if error occures during filtering.
 */
+ (NSArray *)filterTestCases:(NSArray *)allTestCases
               onlyTestCases:(NSArray *)onlyTestCases
            skippedTestCases:(NSArray *)skippedTestCases
                       error:(NSString **)error;

- (instancetype)initWithBuildSettings:(NSDictionary *)buildSettings
                        simulatorInfo:(SimulatorInfo *)simulatorInfo
                     focusedTestCases:(NSArray *)focusedTestCases
                         allTestCases:(NSArray *)allTestCases
                            arguments:(NSArray *)arguments
                          environment:(NSDictionary *)environment
                       freshSimulator:(BOOL)freshSimulator
                       resetSimulator:(BOOL)resetSimulator
                 newSimulatorInstance:(BOOL)newSimulatorInstance
            noResetSimulatorOnFailure:(BOOL)noResetSimulatorOnFailure
                         freshInstall:(BOOL)freshInstall
                          testTimeout:(NSInteger)testTimeout
                            reporters:(NSArray *)reporters
                   processEnvironment:(NSDictionary *)processEnvironment;

- (BOOL)runTests;

- (NSMutableArray *)commonTestArguments;
- (NSArray *)testArgumentsWithSpecifiedTestsToRun;
- (NSDictionary *)testEnvironmentWithSpecifiedTestConfiguration;

- (NSMutableDictionary *)otestEnvironmentWithOverrides:(NSDictionary *)overrides;

@end
