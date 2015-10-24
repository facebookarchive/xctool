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


#import "OtestQuery.h"

#import <dlfcn.h>
#import <objc/objc-runtime.h>
#import <objc/runtime.h>
#import <stdio.h>

#import "DuplicateTestNameFix.h"
#import "NSInvocationInSetFix.h"
#import "ParseTestName.h"
#import "SenIsSuperclassOfClassPerformanceFix.h"
#import "TestingFramework.h"

@implementation OtestQuery

/**
 Crawls through the test suite hierarchy and returns a list of all test case
 names in the format of ...

   @[@"-[SomeClass someMethod]",
     @"-[SomeClass otherMethod]"]
 */
+ (NSArray *)testNamesFromSuite:(id)testSuite
{
  NSMutableArray *names = [NSMutableArray array];

  for (id test in TestsFromSuite(testSuite)) {
    NSString *name = [test performSelector:@selector(description)];
    NSAssert(name != nil, @"Can't get name for test: %@", test);
    [names addObject:name];
  }

  return names;
}

+ (void)queryTestBundlePath:(NSString *)testBundlePath
{
  NSString *outputFile = [NSProcessInfo processInfo].environment[@"OTEST_QUERY_OUTPUT_FILE"];
  NSAssert(outputFile, @"Output path wasn't set in the enviroment: %@", [NSProcessInfo processInfo].environment);
  NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:outputFile];

  NSBundle *bundle = [NSBundle bundleWithPath:testBundlePath];
  if (!bundle) {
    fprintf(stderr, "Bundle '%s' does not identify an accessible bundle directory.\n",
            [testBundlePath UTF8String]);
    _exit(kBundleOpenError);
  }

  NSDictionary *framework = FrameworkInfoForTestBundleAtPath(testBundlePath);
  if (!framework) {
    const char *bundleExtension = [[testBundlePath pathExtension] UTF8String];
    fprintf(stderr, "The bundle extension '%s' is not supported.\n", bundleExtension);
    _exit(kUnsupportedFramework);
  }

  if (![bundle executablePath]) {
    fprintf(stderr, "The bundle at %s does not contain an executable.\n", [testBundlePath UTF8String]);
    _exit(kMissingExecutable);
  }

  // Make sure the 'SenTest' or 'XCTest' preference is cleared before we load the
  // test bundle - otherwise otest-query will accidentally start running tests.
  //
  // Instead of seeing the JSON list of test methods, you'll see output like ...
  //
  //   Test Suite 'All tests' started at 2013-11-07 23:47:46 +0000
  //   Test Suite 'All tests' finished at 2013-11-07 23:47:46 +0000.
  //   Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
  //
  // Here's what happens -- As soon as we dlopen() the test bundle, it will also
  // trigger the linker to load SenTestingKit.framework or XCTest.framework since
  // those are linked by the test bundle.  And, as soon as the testing framework
  // loads, the class initializer '+[SenTestSuite initialize]' is triggered.  If
  // the initializer sees that the 'SenTest' preference is set, it goes ahead
  // and runs tests.
  //
  // By clearing the preference, we can prevent tests from running.
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:
   [framework objectForKey:kTestingFrameworkFilterTestArgsKey]];
  [[NSUserDefaults standardUserDefaults] synchronize];

  // We use dlopen() instead of -[NSBundle loadAndReturnError] because, if
  // something goes wrong, dlerror() gives us a much more helpful error message.
  if (dlopen([[bundle executablePath] UTF8String], RTLD_LAZY) == NULL) {
    fprintf(stderr, "%s\n", dlerror());
    _exit(kDLOpenError);
  }

  [[NSBundle allFrameworks] makeObjectsPerformSelector:@selector(principalClass)];

  XTApplySenIsSuperclassOfClassPerformanceFix();
  ApplyDuplicateTestNameFix([framework objectForKey:kTestingFrameworkTestProbeClassName],
                            [framework objectForKey:kTestingFrameworkTestSuiteClassName]);

  Class testSuiteClass = NSClassFromString([framework objectForKey:kTestingFrameworkTestSuiteClassName]);
  NSCAssert(testSuiteClass, @"Should have *TestSuite class");

  // By setting `-(XC|Sen)Test None`, we'll make `-[(XC|Sen)TestSuite allTests]`
  // return all tests.
  [[NSUserDefaults standardUserDefaults] setObject:@"None"
                                            forKey:[framework objectForKey:kTestingFrameworkFilterTestArgsKey]];
  id allTestsSuite = [testSuiteClass performSelector:@selector(allTests)];
  NSCAssert(allTestsSuite, @"Should have gotten a test suite from allTests");

  NSArray *fullTestNames = [self testNamesFromSuite:allTestsSuite];
  NSMutableArray *testNames = [NSMutableArray array];

  for (NSString *fullTestName in fullTestNames) {
    NSString *className = nil;
    NSString *methodName = nil;
    ParseClassAndMethodFromTestName(&className, &methodName, fullTestName);

    [testNames addObject:[NSString stringWithFormat:@"%@/%@", className, methodName]];
  }

  [testNames sortUsingSelector:@selector(compare:)];

  NSData *json = [NSJSONSerialization dataWithJSONObject:testNames options:0 error:nil];
  [fileHandle writeData:json];
  _exit(kSuccess);
}

@end
