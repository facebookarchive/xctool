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

@interface OCUnitTestRunner : NSObject {
@public
  NSDictionary *_buildSettings;
  NSString *_senTestList;
  NSArray *_arguments;
  NSDictionary *_environment;
  BOOL _garbageCollection;
  BOOL _freshSimulator;
  BOOL _freshInstall;
  NSString *_simulatorType;
  NSArray *_reporters;
}

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

/**
 * Transforms a list of test cases (e.g. 'SomeClass/testFoo') into the most
 * concise form.
 *
 * This exists for a cosmetic reason.  If you run otest and explicitly specify
 * each test to be run (e.g. `-SenTest Cls1/testA,Cls2/testB,Cls2/testC`), then
 * otest will consider each test case to be its own "suite".  This means it will
 * emit the normal suite started and suite ended banners before and after running
 * the test, and so you end up with lots of extra output.  If a test bundle had
 * 10 test cases and we explicitly specified each of them, otest would treat those
 * as 10 separate test suites even if they were each in the same class.
 *
 * We can compensate for this by reducing the `-SenTest` list to the shortest
 * form possible. e.g. --
 *
 *   - If we're running all test cases in a given bundle, that can be expressed
 *     as 'All'.
 *   - If we're running all test cases for a given class, then we can express
 *     that just as 'SomeClass' rather than 'SomeClass/test1,SomeClass/test2,
 *     SomeClass/test3'.
 *
 * @param senTestList Array in the form of ['Cls1/test1,Cls2/test1,Cls2/test2']
 * @param allTestCases Array in the same form as senTestList.
 * @return A string meant to be passed as the `-SenTest` argument.
 */
+ (NSString *)reduceSenTestListToBroadestForm:(NSArray *)senTestList
                                 allTestCases:(NSArray *)allTestCases;

- (id)initWithBuildSettings:(NSDictionary *)buildSettings
                senTestList:(NSString *)senTestList
                  arguments:(NSArray *)arguments
                environment:(NSDictionary *)environment
          garbageCollection:(BOOL)garbageCollection
             freshSimulator:(BOOL)freshSimulator
               freshInstall:(BOOL)freshInstall
              simulatorType:(NSString *)simulatorType
                  reporters:(NSArray *)reporters;

- (BOOL)runTestsWithError:(NSString **)error;

- (NSArray *)otestArguments;
- (NSDictionary *)otestEnvironmentWithOverrides:(NSDictionary *)overrides;

- (NSString *)testBundlePath;

@end
