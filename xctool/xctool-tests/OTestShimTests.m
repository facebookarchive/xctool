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

#import "ContainsException.h"
#import "OCUnitIOSLogicTestRunner.h"
#import "OCUnitIOSLogicTestQueryRunner.h"
#import "ReporterEvents.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"

@interface OTestShimTests : SenTestCase

@end

static NSArray *AllTestCasesInIOSTestBundle(NSString *bundlePath)
{
  NSString *error = nil;
  NSString *latestSDK = GetAvailableSDKsAndAliases()[@"iphonesimulator"];
  NSString *builtProductsDir = [bundlePath stringByDeletingLastPathComponent];
  NSString *fullProductName = [bundlePath lastPathComponent];
  NSDictionary *buildSettings = @{
    kBuiltProductsDir : builtProductsDir,
    kFullProductName : fullProductName,
    kSdkName : latestSDK,
  };
  OCUnitIOSLogicTestQueryRunner *runner = [[OCUnitIOSLogicTestQueryRunner alloc] initWithBuildSettings:buildSettings
                                                                                           withCpuType:CPU_TYPE_ANY];
  NSArray *allTests = [runner runQueryWithError:&error];
  NSCAssert(error == nil, @"Error while querying test cases: %@", error);

  return allTests;
}

static NSTask *otestShimTask(NSString *settingsPath, NSString *targetName, NSString *bundlePath, NSArray *focusedTests, NSArray *allTests)
{
  // Make sure supplied files actually exist at their supposed paths.
  NSCAssert([[NSFileManager defaultManager] fileExistsAtPath:bundlePath], @"Bundle does not exist at '%@'", bundlePath);
  NSCAssert([[NSFileManager defaultManager] fileExistsAtPath:settingsPath], @"Settings dump does not exist at '%@'", bundlePath);

  // Get pre-dumped build settings
  NSString *output = [NSString stringWithContentsOfFile:settingsPath
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
  NSDictionary *allSettings = BuildSettingsFromOutput(output);

  // set up an OCUnitIOSLogicTestRunner
  OCUnitIOSLogicTestRunner *runner = [[OCUnitIOSLogicTestRunner alloc] initWithBuildSettings:allSettings[targetName]
                                                                            focusedTestCases:focusedTests
                                                                                allTestCases:allTests
                                                                                   arguments:@[]
                                                                                 environment:@{}
                                                                           garbageCollection:NO
                                                                              freshSimulator:NO
                                                                                freshInstall:NO
                                                                               simulatorType:nil
                                                                                   reporters:@[]];

  NSTask *task = [runner otestTaskWithTestBundle: bundlePath];
  [runner release];

  // Make sure launch path is accessible.
  NSString *launchPath = [task launchPath];
  NSCAssert([[NSFileManager defaultManager] fileExistsAtPath:launchPath], @"The executable file '%@' does not exist.", launchPath);

  return task;
}

// returns nil when an error is encountered
static NSArray *RunOtestAndParseResult(NSTask *task)
{
  NSMutableArray *resultBuilder = [[NSMutableArray alloc] init];

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

  return [resultBuilder autorelease];
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

  NSArray *allTests = AllTestCasesInIOSTestBundle(bundlePath);
  NSTask *task = otestShimTask(settingsPath, targetName, bundlePath, testList, allTests);
  NSArray *events = RunOtestAndParseResult(task);
  assertThat(events, isNot(nilValue()));
  assertThat(@([events count]), is(@4));
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
  // Only run if XCTest is available.
  NSString *frameworkDirPath = [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/Frameworks/XCTest.framework"];
  if (![[NSFileManager defaultManager] fileExistsAtPath:frameworkDirPath])
    return;

  NSString *bundlePath = TEST_DATA @"tests-ios-test-bundle/XCTest_Assertion.xctest";
  NSString *targetName = @"XCTest_Assertion";
  NSString *settingsPath = TEST_DATA @"TestProject-Assertion-XCTest_Assertion-showBuildSettings.txt";
  NSArray *testList = @[ @"XCTest_Assertion/testAssertionFailure" ];
  NSString *methodName = @"-[XCTest_Assertion testAssertionFailure]";

  NSArray *allTests = AllTestCasesInIOSTestBundle(bundlePath);
  NSTask *task = otestShimTask(settingsPath, targetName, bundlePath, testList, allTests);
  NSArray *events = RunOtestAndParseResult(task);
  assertThat(events, isNot(nilValue()));
  assertThat(@([events count]), is(@4));
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

  NSArray *allTests = AllTestCasesInIOSTestBundle(bundlePath);
  NSTask *task = otestShimTask(settingsPath, targetName, bundlePath, testList, allTests);
  NSArray *events = RunOtestAndParseResult(task);
  assertThat(events, isNot(nilValue()));
  assertThat(@([events count]), is(@5));
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
  // Only run if XCTest is available.
  NSString *frameworkDirPath = [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/Frameworks/XCTest.framework"];
  if (![[NSFileManager defaultManager] fileExistsAtPath:frameworkDirPath])
    return;

  NSString *bundlePath = TEST_DATA @"tests-ios-test-bundle/XCTest_Assertion.xctest";
  NSString *targetName = @"XCTest_Assertion";
  NSString *settingsPath = TEST_DATA @"TestProject-Assertion-XCTest_Assertion-showBuildSettings.txt";
  NSArray *testList = @[ @"XCTest_Assertion/testExpectedAssertionIsSilent" ];
  NSString *methodName = @"-[XCTest_Assertion testExpectedAssertionIsSilent]";

  NSArray *allTests = AllTestCasesInIOSTestBundle(bundlePath);
  NSTask *task = otestShimTask(settingsPath, targetName, bundlePath, testList, allTests);
  NSArray *events = RunOtestAndParseResult(task);
  assertThat(events, isNot(nilValue()));
  assertThat(@([events count]), is(@5));
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

  NSArray *allTests = AllTestCasesInIOSTestBundle(bundlePath);
  NSTask *task = otestShimTask(settingsPath, targetName, bundlePath, testList, allTests);
  NSArray *events = RunOtestAndParseResult(task);
  assertThat(events, isNot(nilValue()));
  assertThat(@([events count]), is(@4));
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
  // Only run if XCTest is available.
  NSString *frameworkDirPath = [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/Frameworks/XCTest.framework"];
  if (![[NSFileManager defaultManager] fileExistsAtPath:frameworkDirPath])
    return;

  NSString *bundlePath = TEST_DATA @"tests-ios-test-bundle/XCTest_Assertion.xctest";
  NSString *targetName = @"XCTest_Assertion";
  NSString *settingsPath = TEST_DATA @"TestProject-Assertion-XCTest_Assertion-showBuildSettings.txt";
  NSArray *testList = @[ @"XCTest_Assertion/testExpectedAssertionMissingIsNotSilent" ];

  NSArray *allTests = AllTestCasesInIOSTestBundle(bundlePath);
  NSTask *task = otestShimTask(settingsPath, targetName, bundlePath, testList, allTests);
  NSArray *events = RunOtestAndParseResult(task);
  assertThat(events, isNot(nilValue()));
  assertThat(@([events count]), is(@4));
  NSDictionary *testEndEvent = ExtractEvent(events, kReporter_Events_EndTest);
  assertThat(testEndEvent, hasKey(@"exceptions"));
  NSArray *exceptions = testEndEvent[@"exceptions"];
  assertThat(exceptions, hasCountOf(1));
  NSDictionary *exception = exceptions[0];
  assertThat(exception, hasKey(@"reason"));
  NSString *reason = exception[@"reason"];
  assertThat(reason, containsString(@"[GOOD1]"));
}

@end
