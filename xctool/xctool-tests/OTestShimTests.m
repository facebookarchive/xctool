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

#import <SenTestingKit/SenTestingKit.h>

#import "ContainsAssertionFailure.h"
#import "OCUnitIOSLogicTestQueryRunner.h"
#import "OCUnitIOSLogicTestRunner.h"
#import "OCUnitOSXLogicTestQueryRunner.h"
#import "OCUnitOSXLogicTestRunner.h"
#import "ReporterEvents.h"
#import "TaskUtil.h"
#import "TestUtil.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

@interface OTestShimTests : SenTestCase
@end

static NSArray *AllTestCasesInTestBundle(NSString *sdkName,
                                         Class testQueryClass,
                                         NSString *bundlePath)
{
  NSString *error = nil;
  NSString *latestSDK = GetAvailableSDKsAndAliases()[sdkName];
  NSString *builtProductsDir = [bundlePath stringByDeletingLastPathComponent];
  NSString *fullProductName = [bundlePath lastPathComponent];
  NSDictionary *buildSettings = @{
                                  Xcode_BUILT_PRODUCTS_DIR : builtProductsDir,
                                  Xcode_FULL_PRODUCT_NAME : fullProductName,
                                  Xcode_SDK_NAME : latestSDK,
                                  };
  OCUnitTestQueryRunner *runner = [[testQueryClass alloc] initWithBuildSettings:buildSettings
                                                                     withCpuType:CPU_TYPE_ANY];
  NSArray *allTests = [runner runQueryWithError:&error];
  NSCAssert(error == nil, @"Error while querying test cases: %@", error);

  return allTests;
}

static NSArray *AllTestCasesInTestBundleOSX(NSString *bundlePath)
{
  return AllTestCasesInTestBundle(@"macosx",
                                  [OCUnitOSXLogicTestQueryRunner class],
                                  bundlePath);
}

static NSArray *AllTestCasesInTestBundleIOS(NSString *bundlePath)
{
  return AllTestCasesInTestBundle(@"iphonesimulator",
                                  [OCUnitIOSLogicTestQueryRunner class],
                                  bundlePath);
}

static NSTask *OtestShimTask(NSString *platformName,
                             Class testRunnerClass,
                             NSString *settingsPath,
                             NSString *targetName,
                             NSString *bundlePath,
                             NSArray *focusedTests,
                             NSArray *allTests)
{
  // Make sure supplied files actually exist at their supposed paths.
  NSCAssert([[NSFileManager defaultManager] fileExistsAtPath:bundlePath], @"Bundle does not exist at '%@'", bundlePath);
  NSCAssert([[NSFileManager defaultManager] fileExistsAtPath:settingsPath], @"Settings dump does not exist at '%@'", settingsPath);

  // Get pre-dumped build settings
  NSString *output = [NSString stringWithContentsOfFile:settingsPath
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
  NSDictionary *allSettings = BuildSettingsFromOutput(output);
  NSMutableDictionary *targetSettings = [NSMutableDictionary
                                         dictionaryWithDictionary:allSettings[targetName]];

  // The faked build settings we use for tests may include paths to Xcode.app
  // that aren't valid on the current machine.  So, we rewrite the SDKROOT
  // so we can be sure it points to a valid directory based off the true Xcode
  // install location.

  NSDictionary *latestSDKInfo = GetAvailableSDKsInfo()[[platformName lowercaseString]];
  NSString *platformNameWithVersion = [platformName stringByAppendingString:latestSDKInfo[@"SDKVersion"]];

  targetSettings[Xcode_SDKROOT] = [NSString stringWithFormat:@"%@/Platforms/%@.platform/Developer/SDKs/%@.sdk",
                                XcodeDeveloperDirPathViaForcedConcreteTask(YES),
                                platformName,
                                platformNameWithVersion];

  // Regardless of whatever is in the build settings, let's pretend and use
  // the latest available SDK.
  targetSettings[Xcode_SDK_NAME] = GetAvailableSDKsAndAliases()[[platformName lowercaseString]];

  // set up an OCUnitIOSLogicTestRunner
  OCUnitIOSLogicTestRunner *runner = [[testRunnerClass alloc] initWithBuildSettings:targetSettings
                                                                   focusedTestCases:focusedTests
                                                                       allTestCases:allTests
                                                                          arguments:@[]
                                                                        environment:@{}
                                                                     freshSimulator:NO
                                                                     resetSimulator:NO
                                                                       freshInstall:NO
                                                                        testTimeout:1
                                                                          reporters:@[]];

  NSTask *task = [runner otestTaskWithTestBundle: bundlePath];

  // Make sure launch path is accessible.
  NSString *launchPath = [task launchPath];
  NSCAssert([[NSFileManager defaultManager] fileExistsAtPath:launchPath], @"The executable file '%@' does not exist.", launchPath);

  return task;
}


static NSTask *OtestShimTaskIOS(NSString *settingsPath, NSString *targetName, NSString *bundlePath, NSArray *focusedTests, NSArray *allTests)
{
  return OtestShimTask(@"iPhoneSimulator",
                       [OCUnitIOSLogicTestRunner class],
                       settingsPath,
                       targetName,
                       bundlePath,
                       focusedTests,
                       allTests);
}

static NSTask *OtestShimTaskOSX(NSString *settingsPath, NSString *targetName, NSString *bundlePath, NSArray *focusedTests, NSArray *allTests)
{
  return OtestShimTask(@"MacOSX",
                       [OCUnitOSXLogicTestRunner class],
                       settingsPath,
                       targetName,
                       bundlePath,
                       focusedTests,
                       allTests);
}

// returns nil when an error is encountered
static NSArray *RunOtestAndParseResult(NSTask *task)
{
  NSMutableArray *resultBuilder = [NSMutableArray array];

  // Set to the null device we don't get the 'Simulator does not seem to be
  // running, or may be running an old SDK.' from the 'sim' launcher.
  [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];

  LaunchTaskAndFeedOuputLinesToBlock(task,
                                     @"running otest/xctest",
                                     ^void (NSString *line) {
    NSError *error = nil;

    if (([line isEqualToString:@""])) {
      return;
    }

    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonObj = [NSJSONSerialization JSONObjectWithData:data
                                                            options:0
                                                              error:&error];

    NSCAssert(!error, @"Each line should be a well-formed JSON object.");
    [resultBuilder addObject:jsonObj];
  });

  // There should have been at least one JSON object.
  if ([resultBuilder count] == 0) {
    return nil;
  }

  return resultBuilder;
}

static NSDictionary *ExtractEvent(NSArray *events, NSString *eventType)
{
  static NSString *eventNameKey = @"event";
  for (NSDictionary *event in events) {
    if ([[event allKeys] containsObject:eventNameKey] &&
        [event[eventNameKey] isEqualToString:eventType]) {
      return event;
    }
  }
  return nil;
}

@implementation OTestShimTests

- (void)testSenTestingKitAssertionFailuresInIOSLogicTestsAreNotSilent
{
  NSString *bundlePath = TEST_DATA @"tests-ios-test-bundle/SenTestingKit_Assertion.octest";
  NSString *targetName = @"SenTestingKit_Assertion";
  NSString *settingsPath = TEST_DATA @"TestProject-Assertion-SenTestingKit_Assertion-showBuildSettings.txt";
  NSArray *testList = @[ @"SenTestingKit_Assertion/testAssertionFailure" ];
  NSString *methodName = @"-[SenTestingKit_Assertion testAssertionFailure]";

  NSArray *allTests = AllTestCasesInTestBundleIOS(bundlePath);
  NSTask *task = OtestShimTaskIOS(settingsPath, targetName, bundlePath, testList, allTests);
  NSArray *events = RunOtestAndParseResult(task);

  NSDictionary *testEndEvent = ExtractEvent(events, kReporter_Events_EndTest);
  assertThat(testEndEvent, hasKey(@"exceptions"));
  NSArray *exceptions = testEndEvent[@"exceptions"];
  assertThat(exceptions, hasCountOf(1));
  NSDictionary *exception = exceptions[0];
  assertThat(exception, hasKey(@"reason"));
  NSString *reason = exception[@"reason"];
  assertThat(reason, containsAssertionFailureFromMethod(methodName));
  assertThat(reason, containsString(@"[GOOD1]"));
}

- (void)testXCTestAssertionFailuresInIOSLogicTestsAreNotSilent
{
  if (!HasXCTestFramework()) {
    return;
  }

  NSString *bundlePath = TEST_DATA @"tests-ios-test-bundle/XCTest_Assertion.xctest";
  NSString *targetName = @"XCTest_Assertion";
  NSString *settingsPath = TEST_DATA @"TestProject-Assertion-XCTest_Assertion-showBuildSettings.txt";
  NSArray *testList = @[ @"XCTest_Assertion/testAssertionFailure" ];
  NSString *methodName = @"-[XCTest_Assertion testAssertionFailure]";

  NSArray *allTests = AllTestCasesInTestBundleIOS(bundlePath);
  NSTask *task = OtestShimTaskIOS(settingsPath, targetName, bundlePath, testList, allTests);
  NSArray *events = RunOtestAndParseResult(task);

  NSDictionary *testEndEvent = ExtractEvent(events, kReporter_Events_EndTest);
  assertThat(testEndEvent, hasKey(@"exceptions"));
  NSArray *exceptions = testEndEvent[@"exceptions"];
  assertThat(exceptions, hasCountOf(1));
  NSDictionary *exception = exceptions[0];
  assertThat(exception, hasKey(@"reason"));
  NSString *reason = exception[@"reason"];
  assertThat(reason, containsAssertionFailureFromMethod(methodName));
  assertThat(reason, containsString(@"[GOOD1]"));
}

- (void)testSenTestingKitExpectedAssertionFailuresInIOSLogicTestsAreSilent
{
  NSString *bundlePath = TEST_DATA @"tests-ios-test-bundle/SenTestingKit_Assertion.octest";
  NSString *targetName = @"SenTestingKit_Assertion";
  NSString *settingsPath = TEST_DATA @"TestProject-Assertion-SenTestingKit_Assertion-showBuildSettings.txt";
  NSArray *testList = @[ @"SenTestingKit_Assertion/testExpectedAssertionIsSilent" ];
  NSString *methodName = @"-[SenTestingKit_Assertion testExpectedAssertionIsSilent]";

  NSArray *allTests = AllTestCasesInTestBundleIOS(bundlePath);
  NSTask *task = OtestShimTaskIOS(settingsPath, targetName, bundlePath, testList, allTests);
  NSArray *events = RunOtestAndParseResult(task);

  NSDictionary *testBeginEvent = ExtractEvent(events, kReporter_Events_BeginTest);
  assertThat(testBeginEvent, hasKey(@"test"));
  assertThat(testBeginEvent[@"test"], is(methodName));
  NSDictionary *testOutputEvent = ExtractEvent(events, kReporter_Events_TestOuput);
  assertThat(testOutputEvent, hasKey(@"output"));
  assertThat(testOutputEvent[@"output"], isNot(containsAssertionFailureFromMethod(methodName)));
  assertThat(testOutputEvent[@"output"], containsString(@"[GOOD1]"));
}

- (void)testXCTestExpectedAssertionFailuresInIOSLogicTestsAreSilent
{
  if (!HasXCTestFramework()) {
    return;
  }

  NSString *bundlePath = TEST_DATA @"tests-ios-test-bundle/XCTest_Assertion.xctest";
  NSString *targetName = @"XCTest_Assertion";
  NSString *settingsPath = TEST_DATA @"TestProject-Assertion-XCTest_Assertion-showBuildSettings.txt";
  NSArray *testList = @[ @"XCTest_Assertion/testExpectedAssertionIsSilent" ];
  NSString *methodName = @"-[XCTest_Assertion testExpectedAssertionIsSilent]";

  NSArray *allTests = AllTestCasesInTestBundleIOS(bundlePath);
  NSTask *task = OtestShimTaskIOS(settingsPath, targetName, bundlePath, testList, allTests);
  NSArray *events = RunOtestAndParseResult(task);

  NSDictionary *testBeginEvent = ExtractEvent(events, kReporter_Events_BeginTest);
  assertThat(testBeginEvent, hasKey(@"test"));
  assertThat(testBeginEvent[@"test"], is(methodName));
  NSDictionary *testOutputEvent = ExtractEvent(events, kReporter_Events_TestOuput);
  assertThat(testOutputEvent, hasKey(@"output"));
  assertThat(testOutputEvent[@"output"], isNot(containsAssertionFailureFromMethod(methodName)));
  assertThat(testOutputEvent[@"output"], containsString(@"[GOOD1]"));
}

- (void)testSenTestingKitMissingExpectedAssertionsAreNotSilent
{
  NSString *bundlePath = TEST_DATA @"tests-ios-test-bundle/SenTestingKit_Assertion.octest";
  NSString *targetName = @"SenTestingKit_Assertion";
  NSString *settingsPath = TEST_DATA @"TestProject-Assertion-SenTestingKit_Assertion-showBuildSettings.txt";
  NSArray *testList = @[ @"SenTestingKit_Assertion/testExpectedAssertionMissingIsNotSilent" ];

  NSArray *allTests = AllTestCasesInTestBundleIOS(bundlePath);
  NSTask *task = OtestShimTaskIOS(settingsPath, targetName, bundlePath, testList, allTests);
  NSArray *events = RunOtestAndParseResult(task);

  NSDictionary *testEndEvent = ExtractEvent(events, kReporter_Events_EndTest);
  assertThat(testEndEvent, hasKey(@"exceptions"));
  NSArray *exceptions = testEndEvent[@"exceptions"];
  assertThat(exceptions, hasCountOf(1));
  NSDictionary *exception = exceptions[0];
  assertThat(exception, hasKey(@"reason"));
  NSString *reason = exception[@"reason"];
  assertThat(reason, containsString(@"[GOOD1]"));
}

- (void)testXCTestMissingExpectedAssertionsAreNotSilent
{
  if (!HasXCTestFramework()) {
    return;
  }

  NSString *bundlePath = TEST_DATA @"tests-ios-test-bundle/XCTest_Assertion.xctest";
  NSString *targetName = @"XCTest_Assertion";
  NSString *settingsPath = TEST_DATA @"TestProject-Assertion-XCTest_Assertion-showBuildSettings.txt";
  NSArray *testList = @[ @"XCTest_Assertion/testExpectedAssertionMissingIsNotSilent" ];

  NSArray *allTests = AllTestCasesInTestBundleIOS(bundlePath);
  NSTask *task = OtestShimTaskIOS(settingsPath, targetName, bundlePath, testList, allTests);
  NSArray *events = RunOtestAndParseResult(task);

  NSDictionary *testEndEvent = ExtractEvent(events, kReporter_Events_EndTest);
  assertThat(testEndEvent, hasKey(@"exceptions"));
  NSArray *exceptions = testEndEvent[@"exceptions"];
  assertThat(exceptions, hasCountOf(1));
  NSDictionary *exception = exceptions[0];
  assertThat(exception, hasKey(@"reason"));
  NSString *reason = exception[@"reason"];
  assertThat(reason, containsString(@"[GOOD1]"));
}

- (void)testOutputBeforeTestBundleStartsIsCaptured
{
  NSString *bundlePath = TEST_DATA @"TestThatThrowsExceptionOnStart/Build/Products/Debug/TestThatThrowsExceptionOnStart.octest";
  NSString *targetName = @"TestThatThrowsExceptionOnStart";
  NSString *settingsPath = TEST_DATA @"TestThatThrowsExceptionOnStart/TestThatThrowsExceptionOnStart-showBuildSettings.txt";
  NSArray *testList = @[ @"TestThatThrowsExceptionOnStart/testExample" ];

  NSArray *allTests = AllTestCasesInTestBundleOSX(bundlePath);
  NSTask *task = OtestShimTaskOSX(settingsPath, targetName, bundlePath, testList, allTests);
  NSArray *events = RunOtestAndParseResult(task);

  NSString *output = [SelectEventFields(events, kReporter_Events_OutputBeforeTestBundleStarts, kReporter_OutputBeforeTestBundleStarts_OutputKey)
                      componentsJoinedByString:@""];

  assertThat(output, containsString(@"Terminating app due to uncaught exception"));
}

- (void)testSenTestingKitExceptionIsThrownWhenTestTimeoutIsHit
{
  NSString *bundlePath = TEST_DATA @"tests-ios-test-bundle/TestProject-LibraryTests.octest";
  NSString *targetName = @"TestProject-LibraryTests";
  NSString *settingsPath = TEST_DATA @"TestProject-Library-TestProject-LibraryTests-showBuildSettings.txt";
  NSArray *testList = @[ @"SomeTests/testTimeout" ];

  NSArray *allTests = AllTestCasesInTestBundleIOS(bundlePath);
  NSTask *task = OtestShimTaskIOS(settingsPath, targetName, bundlePath, testList, allTests);
  NSArray *events = RunOtestAndParseResult(task);

  NSDictionary *testOutputEvent = ExtractEvent(events, kReporter_Events_TestOuput);
  assertThat(testOutputEvent, hasKey(@"output"));
  NSString *testOutput = testOutputEvent[@"output"];
  assertThat(testOutput, containsString(@"Test -[SomeTests testTimeout] ran longer than specified test time limit: 1 second(s)"));
}

- (void)testXCTestExceptionIsThrownWhenTestTimeoutIsHit
{
  NSString *bundlePath = TEST_DATA @"tests-ios-test-bundle/TestProject-Library-XCTest-iOSTests.xctest";
  NSString *targetName = @"TestProject-Library-XCTest-iOSTests";
  NSString *settingsPath = TEST_DATA @"TestProject-Library-XCTest-iOS-TestProject-Library-XCTest-iOSTests-showBuildSettings-iphoneos.txt";
  NSArray *testList = @[ @"SomeTests/testTimeout" ];

  NSArray *allTests = AllTestCasesInTestBundleIOS(bundlePath);
  NSTask *task = OtestShimTaskIOS(settingsPath, targetName, bundlePath, testList, allTests);
  NSArray *events = RunOtestAndParseResult(task);

  NSDictionary *testOutputEvent = ExtractEvent(events, kReporter_Events_TestOuput);
  assertThat(testOutputEvent, hasKey(@"output"));
  NSString *testOutput = testOutputEvent[@"output"];
  assertThat(testOutput, containsString(@"Test -[SomeTests testTimeout] ran longer than specified test time limit: 1 second(s)"));
}

@end
