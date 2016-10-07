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

#import <XCTest/XCTest.h>

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

@interface OTestShimTests : XCTestCase
@end

static NSArray *AllTestCasesInTestBundle(NSString *sdkName,
                                         Class testQueryClass,
                                         NSString *bundlePath)
{
  NSString *error = nil;
  NSString *latestSDK = GetAvailableSDKsAndAliases()[sdkName];
  NSString *builtProductsDir = [bundlePath stringByDeletingLastPathComponent];
  NSString *fullProductName = [bundlePath lastPathComponent];
  SimulatorInfo *simulatorInfo = [[SimulatorInfo alloc] init];
  simulatorInfo.buildSettings = @{
    Xcode_BUILT_PRODUCTS_DIR : builtProductsDir,
    Xcode_FULL_PRODUCT_NAME : fullProductName,
    Xcode_SDK_NAME : latestSDK,
    Xcode_TARGETED_DEVICE_FAMILY : @"1",
    Xcode_PLATFORM_NAME: @"iphonesimulator",
  };
  OCUnitTestQueryRunner *runner = [[testQueryClass alloc] initWithSimulatorInfo:simulatorInfo];
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
                             NSArray *allTests,
                             NSString **otestShimOutputPath)
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

  targetSettings[Xcode_BUILT_PRODUCTS_DIR] = [bundlePath stringByDeletingLastPathComponent];
  targetSettings[Xcode_TARGET_BUILD_DIR] = [bundlePath stringByDeletingLastPathComponent];
  targetSettings[Xcode_FULL_PRODUCT_NAME] = [bundlePath lastPathComponent];

  // set up an OCUnitIOSLogicTestRunner
  OCUnitIOSLogicTestRunner *runner = [[testRunnerClass alloc] initWithBuildSettings:targetSettings
                                                                      simulatorInfo:[[SimulatorInfo alloc] init]
                                                                   focusedTestCases:focusedTests
                                                                       allTestCases:allTests
                                                                          arguments:@[]
                                                                        environment:@{}
                                                                     freshSimulator:NO
                                                                     resetSimulator:NO
                                                               newSimulatorInstance:NO
                                                          noResetSimulatorOnFailure:NO
                                                                       freshInstall:NO
                                                                    waitForDebugger:NO
                                                                        testTimeout:1
                                                                          reporters:@[]
                                                                 processEnvironment:@{}];
  NSTask *task = [runner otestTaskWithTestBundle:bundlePath otestShimOutputPath:otestShimOutputPath];
  if ([platformName isEqual:@"MacOSX"]) {
    [task setCurrentDirectoryPath:targetSettings[Xcode_BUILT_PRODUCTS_DIR]];
  }

  // Make sure launch path is accessible.
  NSString *launchPath = [task launchPath];
  NSCAssert([[NSFileManager defaultManager] fileExistsAtPath:launchPath], @"The executable file '%@' does not exist.", launchPath);

  return task;
}


static NSTask *OtestShimTaskIOS(NSString *settingsPath, NSString *targetName, NSString *bundlePath, NSArray *focusedTests, NSArray *allTests, NSString **otestShimOutputPath)
{
  return OtestShimTask(@"iPhoneSimulator",
                       [OCUnitIOSLogicTestRunner class],
                       settingsPath,
                       targetName,
                       bundlePath,
                       focusedTests,
                       allTests,
                       otestShimOutputPath);
}

static NSTask *OtestShimTaskOSX(NSString *settingsPath, NSString *targetName, NSString *bundlePath, NSArray *focusedTests, NSArray *allTests, NSString **otestShimOutputPath)
{
  return OtestShimTask(@"MacOSX",
                       [OCUnitOSXLogicTestRunner class],
                       settingsPath,
                       targetName,
                       bundlePath,
                       focusedTests,
                       allTests,
                       otestShimOutputPath);
}

// returns nil when an error is encountered
static NSArray *RunOtestAndParseResult(NSTask *task, NSString *otestShimOutputPath)
{
  NSMutableArray *resultBuilder = [NSMutableArray array];

  if (otestShimOutputPath) {
    LaunchTaskAndFeedSimulatorOutputAndOtestShimEventsToBlock(
      task,
      @"running otest/xctest",
      otestShimOutputPath,
      ^(int fd, NSString *line) {
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
  } else {
    LaunchTaskAndFeedOuputLinesToBlock(task,
                                       @"running otest/xctest",
                                       ^void (int fd, NSString *line) {
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
  }

  // There should have been at least one JSON object.
  if ([resultBuilder count] == 0) {
    return nil;
  }

  return [resultBuilder copy];
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

+ (void)setUp
{
  [SimulatorInfo prepare];
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
  NSString *otestShimOutputPath;
  NSTask *task = OtestShimTaskIOS(settingsPath, targetName, bundlePath, testList, allTests, &otestShimOutputPath);
  NSArray *events = RunOtestAndParseResult(task, otestShimOutputPath);

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
  NSString *otestShimOutputPath;
  NSTask *task = OtestShimTaskIOS(settingsPath, targetName, bundlePath, testList, allTests, &otestShimOutputPath);
  NSArray *events = RunOtestAndParseResult(task, otestShimOutputPath);

  NSDictionary *testBeginEvent = ExtractEvent(events, kReporter_Events_BeginTest);
  assertThat(testBeginEvent, hasKey(@"test"));
  assertThat(testBeginEvent[@"test"], is(methodName));
  NSDictionary *testOutputEvent = ExtractEvent(events, kReporter_Events_TestOuput);
  assertThat(testOutputEvent, hasKey(@"output"));
  assertThat(testOutputEvent[@"output"], isNot(containsAssertionFailureFromMethod(methodName)));
  assertThat(testOutputEvent[@"output"], containsString(@"[GOOD1]"));
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
  NSString *otestShimOutputPath;
  NSTask *task = OtestShimTaskIOS(settingsPath, targetName, bundlePath, testList, allTests, &otestShimOutputPath);
  NSArray *events = RunOtestAndParseResult(task, otestShimOutputPath);

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
  NSString *bundlePath = TEST_DATA @"TestThatThrowsExceptionOnStart/Build/Products/Debug/TestThatThrowsExceptionOnStart.xctest";
  NSString *targetName = @"TestThatThrowsExceptionOnStart";
  NSString *settingsPath = TEST_DATA @"TestThatThrowsExceptionOnStart/TestThatThrowsExceptionOnStart-showBuildSettings.txt";
  NSArray *testList = @[ @"TestThatThrowsExceptionOnStart/testExample" ];

  NSArray *allTests = AllTestCasesInTestBundleOSX(bundlePath);
  NSString *otestShimOutputPath;
  NSTask *task = OtestShimTaskOSX(settingsPath, targetName, bundlePath, testList, allTests, &otestShimOutputPath);
  NSArray *events = RunOtestAndParseResult(task, otestShimOutputPath);

  NSMutableArray *significantEvents = [NSMutableArray new];
  NSMutableArray *simOutputEvents = [NSMutableArray new];
  for (NSDictionary *event in events) {
    if ([event[kReporter_Event_Key] isEqual:kReporter_Events_SimulatorOuput]) {
      [simOutputEvents addObject:event];
    } else {
      [significantEvents addObject:event];
    }
  }

  assertThat(significantEvents, hasCountOf(2));
  assertThat(significantEvents[0][@"event"], is(kReporter_Events_BeginTestSuite));
  assertThat(significantEvents[1][@"event"], is(kReporter_Events_EndTestSuite));
  assertThat(@(simOutputEvents.count), greaterThan(@10));
}

- (void)testXCTestExceptionIsThrownWhenSuiteTimeoutIsHitInSetup
{
  if (ToolchainIsXcode8OrBetter()) {
    // TODO: Should work in Xcode 8 but doesn't work currenly
    PrintTestNotRelevantNotice();
    return;
  }
  NSString *bundlePath = TEST_DATA @"tests-ios-test-bundle/TestProject-Library-XCTest-iOSTests.xctest";
  NSString *targetName = @"TestProject-Library-XCTest-iOSTests";
  NSString *settingsPath = TEST_DATA @"TestProject-Library-XCTest-iOS-TestProject-Library-XCTest-iOSTests-showBuildSettings-iphonesimulator.txt";
  NSArray *testList = @[ @"SetupTimeoutTests/testNothing" ];
  
  NSArray *allTests = AllTestCasesInTestBundleIOS(bundlePath);
  NSString *otestShimOutputPath;
  NSTask *task = OtestShimTaskIOS(settingsPath, targetName, bundlePath, testList, allTests, &otestShimOutputPath);
  NSArray *events = RunOtestAndParseResult(task, otestShimOutputPath);
  
  NSDictionary *testOutputEvent = ExtractEvent(events, kReporter_Events_SimulatorOuput);
  assertThat(testOutputEvent, hasKey(@"output"));
  NSString *testOutput = testOutputEvent[@"output"];
  assertThat(testOutput, containsString(@"Suite SetupTimeoutTests ran longer than combined test time limit: 1 second(s)"));
  if (ToolchainIsXcode7OrBetter()) {
    assertThat(testOutput, containsString(@"(No tests ran, likely stalled in +[SetupTimeoutTests setUp])")); 
  }
}


- (void)testXCTestExceptionIsThrownWhenSuiteTimeoutIsHitInTeardown
{
  if (ToolchainIsXcode8OrBetter()) {
    // TODO: Should work in Xcode 8 but doesn't work currenly
    PrintTestNotRelevantNotice();
    return;
  }
  NSString *bundlePath = TEST_DATA @"tests-ios-test-bundle/TestProject-Library-XCTest-iOSTests.xctest";
  NSString *targetName = @"TestProject-Library-XCTest-iOSTests";
  NSString *settingsPath = TEST_DATA @"TestProject-Library-XCTest-iOS-TestProject-Library-XCTest-iOSTests-showBuildSettings-iphonesimulator.txt";
  NSArray *testList = @[ @"TeardownTimeoutTests/testNothing" ];
  
  NSArray *allTests = AllTestCasesInTestBundleIOS(bundlePath);
  NSString *otestShimOutputPath;
  NSTask *task = OtestShimTaskIOS(settingsPath, targetName, bundlePath, testList, allTests, &otestShimOutputPath);
  NSArray *events = RunOtestAndParseResult(task, otestShimOutputPath);
  
  NSDictionary *testOutputEvent = ExtractEvent(events, kReporter_Events_SimulatorOuput);
  assertThat(testOutputEvent, hasKey(@"output"));
  NSString *testOutput = testOutputEvent[@"output"];
  assertThat(testOutput, containsString(@"Suite TeardownTimeoutTests ran longer than combined test time limit: 1 second(s)"));
  if (ToolchainIsXcode7OrBetter()) {
    assertThat(testOutput, containsString(@"(All tests ran, likely stalled in +[TeardownTimeoutTests tearDown])"));
  }
}

- (void)testXCTestExceptionIsThrownWhenTestTimeoutIsHit
{
  if (ToolchainIsXcode8OrBetter()) {
    // TODO: Should work in Xcode 8 but doesn't work currenly
    PrintTestNotRelevantNotice();
    return;
  }
  NSString *bundlePath = TEST_DATA @"tests-ios-test-bundle/TestProject-Library-XCTest-iOSTests.xctest";
  NSString *targetName = @"TestProject-Library-XCTest-iOSTests";
  NSString *settingsPath = TEST_DATA @"TestProject-Library-XCTest-iOS-TestProject-Library-XCTest-iOSTests-showBuildSettings-iphonesimulator.txt";
  NSArray *testList = @[ @"TimeoutTests/testTimeout" ];

  NSArray *allTests = AllTestCasesInTestBundleIOS(bundlePath);
  NSString *otestShimOutputPath;
  NSTask *task = OtestShimTaskIOS(settingsPath, targetName, bundlePath, testList, allTests, &otestShimOutputPath);
  NSArray *events = RunOtestAndParseResult(task, otestShimOutputPath);

  NSDictionary *testOutputEvent = ExtractEvent(events, kReporter_Events_SimulatorOuput);
  assertThat(testOutputEvent, hasKey(@"output"));
  NSString *testOutput = testOutputEvent[@"output"];
  assertThat(testOutput, containsString(@"Test -[TimeoutTests testTimeout] ran longer than specified test time limit: 1 second(s)"));
}

@end
