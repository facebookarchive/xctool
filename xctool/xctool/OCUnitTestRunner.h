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

#import <Foundation/Foundation.h>

#import "TestRunState.h"
#import "TestingFramework.h"

@interface OCUnitTestRunner : NSObject {
@protected
  NSDictionary *_buildSettings;
  NSArray *_focusedTestCases;
  NSArray *_allTestCases;
  NSArray *_arguments;
  cpu_type_t _cpuType;
  NSDictionary *_environment;
  BOOL _garbageCollection;
  BOOL _freshSimulator;
  BOOL _resetSimulator;
  BOOL _freshInstall;
  NSInteger _testTimeout;
  NSArray *_reporters;
  NSDictionary *_framework;
}

@property (nonatomic, assign) cpu_type_t cpuType;
@property (nonatomic, copy, readonly) NSArray *reporters;

/**
 * Filters a list of test class names to only those that match the
 * senTestList and senTestInvertScope constraints.
 *
 * @param testCases An array of test cases ('ClassA/test1', 'ClassB/test2')
 * @param senTestList SenTestList string.  e.g. "All", "None", "ClsA,ClsB"
 * @param senTestInvertScope YES if scope should be inverted.
 */
+ (NSArray *)filterTestCases:(NSArray *)testCases
             withSenTestList:(NSString *)senTestList
          senTestInvertScope:(BOOL)senTestInvertScope;

- (instancetype)initWithBuildSettings:(NSDictionary *)buildSettings
           focusedTestCases:(NSArray *)focusedTestCases
               allTestCases:(NSArray *)allTestCases
                  arguments:(NSArray *)arguments
                environment:(NSDictionary *)environment
             freshSimulator:(BOOL)freshSimulator
             resetSimulator:(BOOL)resetSimulator
               freshInstall:(BOOL)freshInstall
                testTimeout:(NSInteger)testTimeout
                  reporters:(NSArray *)reporters;

- (BOOL)runTests;

- (NSArray *)testArguments;
- (NSMutableDictionary *)otestEnvironmentWithOverrides:(NSDictionary *)overrides;
- (NSString *)testBundlePath;

@end
