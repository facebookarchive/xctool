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

#import "ContainsArray.h"
#import "EventBuffer.h"
#import "FakeOCUnitTestRunner.h"
#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "OCUnitIOSAppTestRunner.h"
#import "OCUnitIOSLogicTestRunner.h"
#import "OCUnitOSXAppTestRunner.h"
#import "OCUnitOSXLogicTestRunner.h"
#import "OCUnitTestQueryRunner.h"
#import "OCUnitTestRunner.h"
#import "ReporterEvents.h"
#import "SimDevice.h"
#import "Swizzler.h"
#import "TestUtil.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"
#import "XCTestConfiguration.h"
#import "XCTestConfigurationUnarchiver.h"

@interface OCUnitTestRunner ()
@property (nonatomic, copy) SimulatorInfo *simulatorInfo;
@end

static id TestRunnerWithTestListsAndProcessEnv(Class cls, NSDictionary *settings, NSArray *focusedTestCases, NSArray *allTestCases, NSDictionary *processEnvironment)
{
  NSArray *arguments = @[@"-SomeArg", @"SomeVal"];
  NSDictionary *environment = @{@"SomeEnvKey" : @"SomeEnvValue"};

  EventBuffer *eventBuffer = [[EventBuffer alloc] init];

  return [[cls alloc] initWithBuildSettings:settings
                              simulatorInfo:[[SimulatorInfo alloc] init]
                           focusedTestCases:focusedTestCases
                               allTestCases:allTestCases
                                  arguments:arguments
                                environment:environment
                             freshSimulator:NO
                             resetSimulator:NO
                       newSimulatorInstance:NO
                  noResetSimulatorOnFailure:NO
                               freshInstall:NO
                                testTimeout:30
                                  reporters:@[eventBuffer]
                         processEnvironment:processEnvironment];
}


static id TestRunnerWithTestLists(Class cls, NSDictionary *settings, NSArray *focusedTestCases, NSArray *allTestCases)
{
  return TestRunnerWithTestListsAndProcessEnv(cls, settings, focusedTestCases, allTestCases, @{});
}

static id TestRunnerWithTestList(Class cls, NSDictionary *settings, NSArray *testList)
{
  return TestRunnerWithTestListsAndProcessEnv(cls, settings, testList, testList, @{});
}

static id TestRunner(Class cls, NSDictionary *settings)
{
  return TestRunnerWithTestListsAndProcessEnv(cls, settings, @[], @[], @{});
}

static int NumberOfEntries(NSArray *array, NSObject *target)
{
  __block int count = 0;
  [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    if ([obj isEqual:target]) {
      count++;
    }
  }];
  return count;
}

@interface OCUnitTestRunnerTests : XCTestCase
@end

@implementation OCUnitTestRunnerTests

#pragma mark iOS Tests

- (void)runTestsForRunner:(OCUnitTestRunner *)runner andReturnLaunchOptions:(NSDictionary **)outOptions
{
  [Swizzler whileSwizzlingSelector:@selector(launchApplicationWithID:options:error:)
               forInstancesOfClass:[SimDevice class]
                         withBlock:
   ^(SimDevice *m_self, NSString *bundleId, NSDictionary *options, NSError **err) {
     // Pretend it failed, but save the options so we can check it.
     *outOptions = [options copy];
     return -1;
   }
                          runBlock:
   ^{
     [runner runTests];
   }];
}

- (void)testArgsAndEnvArePassedToIOSApplicationTest
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"iOS-Application-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);

  NSMutableDictionary *testSettings = [allSettings[@"TestProjectApplicationTests"] mutableCopy];
  testSettings[@"TEST_HOST"] = TEST_DATA @"FakeApp.app/FakeApp";

  OCUnitTestRunner *runner = TestRunner([OCUnitIOSAppTestRunner class], testSettings);

  NSDictionary *options = nil;
  [self runTestsForRunner:runner andReturnLaunchOptions:&options];

  assertThat(options, notNilValue());
  assertThat(options[@"arguments"],
             containsArray(@[@"-SomeArg",
                             @"SomeVal",
                             ]));
  assertThat(options[@"environment"][@"SomeEnvKey"],
             equalTo(@"SomeEnvValue"));
  assertThat(options[@"environment"][@"OTEST_SHIM_TEST_TIMEOUT"],
             equalTo(@"30"));

}

- (void)testIOSApplicationTestWithBadTesthostFails
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"iOS-Application-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);

  NSMutableDictionary *testSettings = [allSettings[@"TestProjectApplicationTests"] mutableCopy];
  testSettings[@"TEST_HOST"] = @"/var/empty/whee";

  OCUnitTestRunner *runner = TestRunner([OCUnitIOSAppTestRunner class], testSettings);

  NSDictionary *options = nil;
  [self runTestsForRunner:runner andReturnLaunchOptions:&options];

  assertThat(options, nilValue());

  EventBuffer *eventBuffer = runner.reporters[0];
  NSArray *events = [eventBuffer events];

  // A fake test should get inserted to advertise the error.
  assertThat(SelectEventFields(events, kReporter_Events_BeginTest, kReporter_BeginTest_TestKey),
             equalTo(@[@"-[TEST_BUNDLE FAILED_TO_START]"]));

  // And, it should indicate what broke.
  assertThat(SelectEventFields(events, kReporter_Events_TestOuput, kReporter_TestOutput_OutputKey),
             equalTo(@[@"There was a problem starting the test bundle: TEST_HOST not executable."]));

}

- (void)testArgsAndEnvArePassedToIOSLogicTest
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"iOS-Logic-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-LibraryTests"];

  NSArray *launchedTasks;

  OCUnitTestRunner *runner = TestRunner([OCUnitIOSLogicTestRunner class], testSettings);
  runner.simulatorInfo.cpuType = CPU_TYPE_I386;
  [self runTestsForRunner:runner
           andReturnTasks:&launchedTasks];

  assertThatInteger([launchedTasks count], equalToInteger(1));

  assertThat([launchedTasks[0] arguments],
             containsArray(@[@"-SomeArg",
                             @"SomeVal",
                             ]));
  assertThat([launchedTasks[0] environment][@"SIMCTL_CHILD_SomeEnvKey"],
             equalTo(@"SomeEnvValue"));
  assertThat([launchedTasks[0] environment][@"SIMCTL_CHILD_OTEST_SHIM_TEST_TIMEOUT"],
             equalTo(@"30"));
}

- (void)testXctoolTestEnvVarsFromProcessArePassedToIOSLogicTest
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"iOS-Logic-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-LibraryTests"];

  NSArray *launchedTasks;

  OCUnitTestRunner *runner = TestRunnerWithTestListsAndProcessEnv(
    [OCUnitIOSLogicTestRunner class],
    testSettings,
    @[],
    @[],
    @{
      @"XCTOOL_TEST_ENV_FOO": @"bar",
      @"NO_PASS_THROUGH": @"baz",
    });
  runner.simulatorInfo.cpuType = CPU_TYPE_I386;
  [self runTestsForRunner:runner
           andReturnTasks:&launchedTasks];

  assertThatInteger([launchedTasks count], equalToInteger(1));

  assertThat([launchedTasks[0] environment][@"XCTOOL_TEST_ENV_FOO"],
             nilValue());
  assertThat([launchedTasks[0] environment][@"FOO"],
             nilValue());
  assertThat([launchedTasks[0] environment][@"SIMCTL_CHILD_FOO"],
             equalTo(@"bar"));
  assertThat([launchedTasks[0] environment][@"NO_PASS_THROUGH"],
             nilValue());
  assertThat([launchedTasks[0] environment][@"SIMCTL_CHILD_NO_PASS_THROUGH"],
             nilValue());
}

#pragma mark OSX Tests

- (void)runTestsForRunner:(OCUnitTestRunner *)runner
           andReturnTasks:(NSArray **)launchedTasks
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [runner runTests];
    *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
  }];
}

- (void)testArgsAndEnvArePassedToOSXApplicationTest
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"OSX-Application-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);

  NSMutableDictionary *testSettings = [allSettings[@"TestProject-App-OSXTests"] mutableCopy];
  testSettings[@"TEST_HOST"] = TEST_DATA @"FakeApp.app/FakeApp";

  NSArray *launchedTasks;

  OCUnitTestRunner *runner = TestRunner([OCUnitOSXAppTestRunner class], testSettings);
  [self runTestsForRunner:runner
           andReturnTasks:&launchedTasks];

  assertThatInteger([launchedTasks count], equalToInteger(1));
  assertThat([launchedTasks[0] arguments],
             containsArray(@[@"-SomeArg",
                             @"SomeVal",
                             ]));
  assertThat([launchedTasks[0] environment][@"SomeEnvKey"],
             equalTo(@"SomeEnvValue"));
  assertThat([launchedTasks[0] environment][@"OTEST_SHIM_TEST_TIMEOUT"],
             equalTo(@"30"));
}

- (void)testOSXApplicationTestWithBadTesthostFails
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"OSX-Application-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);

  NSMutableDictionary *testSettings = [allSettings[@"TestProject-App-OSXTests"] mutableCopy];
  testSettings[@"TEST_HOST"] = @"/var/empty/whee";

  NSArray *launchedTasks;

  OCUnitTestRunner *runner = TestRunner([OCUnitOSXAppTestRunner class], testSettings);
  [self runTestsForRunner:runner
           andReturnTasks:&launchedTasks];

  assertThatInteger([launchedTasks count], equalToInteger(0));

  EventBuffer *eventBuffer = runner.reporters[0];
  NSArray *events = [eventBuffer events];

  // A fake test should get inserted to advertise the error.
  assertThat(SelectEventFields(events, kReporter_Events_BeginTest, kReporter_BeginTest_TestKey),
             equalTo(@[@"-[TEST_BUNDLE FAILED_TO_START]"]));

  // And, it should indicate what broke.
  assertThat(SelectEventFields(events, kReporter_Events_TestOuput, kReporter_TestOutput_OutputKey),
             equalTo(@[@"There was a problem starting the test bundle: TEST_HOST not executable."]));
}

- (void)testArgsAndEnvArePassedToOSXLogicTest
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"OSX-Logic-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-Library-OSXTests"];

  NSArray *launchedTasks = nil;

  OCUnitTestRunner *runner = TestRunner([OCUnitOSXLogicTestRunner class], testSettings);
  [self runTestsForRunner:runner
           andReturnTasks:&launchedTasks];

  assertThatInteger([launchedTasks count], equalToInteger(1));

  NSArray *arguments = [launchedTasks[0] arguments];
  assertThat(arguments,
             containsArray(@[@"-SomeArg",
                             @"SomeVal",
                             ]));
  assertThat([launchedTasks[0] environment][@"SomeEnvKey"],
             equalTo(@"SomeEnvValue"));
  assertThat([launchedTasks[0] environment][@"OTEST_SHIM_TEST_TIMEOUT"],
             equalTo(@"30"));
}

- (void)testXctoolTestEnvVarsFromProcessArePassedToOSXLogicTest
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"OSX-Logic-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-Library-OSXTests"];

  NSArray *launchedTasks = nil;

  OCUnitTestRunner *runner = TestRunnerWithTestListsAndProcessEnv(
    [OCUnitOSXLogicTestRunner class],
    testSettings,
    @[],
    @[],
    @{
      @"XCTOOL_TEST_ENV_FOO": @"bar",
      @"OSX_PASS_THROUGH": @"baz",
    });
  [self runTestsForRunner:runner
           andReturnTasks:&launchedTasks];

  assertThatInteger([launchedTasks count], equalToInteger(1));

  assertThat([launchedTasks[0] environment][@"FOO"],
             equalTo(@"bar"));
  assertThat([launchedTasks[0] environment][@"OSX_PASS_THROUGH"],
             equalTo(@"baz"));
}

- (void)testOSXAppTestWorksWithNoProjectPath
{
  NSDictionary *testSettings = @{
    Xcode_SDK_NAME: @"macosx10.8",
    Xcode_SDKROOT: @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk",
    Xcode_BUILT_PRODUCTS_DIR: TEST_DATA @"TestProject-App-OSX/Build/Products/Debug",
    Xcode_FULL_PRODUCT_NAME: @"TestProject-App-OSXTests.octest",
    Xcode_TEST_HOST: TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX",
    Xcode_PLATFORM_DIR: @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/",
  };

  NSArray *launchedTasks = nil;

  OCUnitTestRunner *runner = TestRunner([OCUnitOSXAppTestRunner class], testSettings);
  [self runTestsForRunner:runner
           andReturnTasks:&launchedTasks];

  assertThatInteger([launchedTasks count], equalToInteger(1));

  assertThat([launchedTasks[0] environment][@"XCInjectBundle"],
            equalTo(TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSXTests.octest"));
  assertThat([launchedTasks[0] environment][@"XCInjectBundleInto"],
             equalTo(TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX"));
}

- (void)testOSXLogicTestWorksWithNoProjectPath
{
  NSDictionary *testSettings = @{
    Xcode_SDK_NAME: @"macosx10.8",
    Xcode_SDKROOT: @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk",
    Xcode_BUILT_PRODUCTS_DIR: TEST_DATA @"tests-osx-test-bundle",
    Xcode_FULL_PRODUCT_NAME: @"TestProject-Library-XCTest-OSXTests.xctest",
    Xcode_PRODUCT_MODULE_NAME: @"TestProject-Library",
  };

  NSArray *launchedTasks = nil;

  OCUnitTestRunner *runner = TestRunner([OCUnitOSXLogicTestRunner class], testSettings);
  [self runTestsForRunner:runner
           andReturnTasks:&launchedTasks];

  assertThatInteger([launchedTasks count], equalToInteger(1));

  NSString *testBundlePath = TEST_DATA @"tests-osx-test-bundle/TestProject-Library-XCTest-OSXTests.xctest";
  if (ToolchainIsXcode7OrBetter()) {
    NSString *XCTestConfigurationFilePath = [launchedTasks[0] environment][@"XCTestConfigurationFilePath"];
    XCTAssertNotNil(XCTestConfigurationFilePath, @"Unepxected environment: %@", [launchedTasks[0] environment]);
    XCTestConfiguration *configuration = [XCTestConfigurationUnarchiver unarchiveFromFile:XCTestConfigurationFilePath];
    XCTAssertNotNil(configuration, @"Couldn't read configuration file at path: %@", XCTestConfigurationFilePath);
    assertThat(configuration.productModuleName, equalTo(@"TestProject-Library"));
    XCTAssert([[configuration.testBundleURL path] hasSuffix:testBundlePath]);
  } else {
    assertThat([launchedTasks[0] arguments], containsArray(@[testBundlePath]));
  }
}

- (void)testTestArgumentsAlwaysIncludesCommonItems
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"OSX-Logic-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-Library-OSXTests"];

  OCUnitTestRunner *runner = TestRunner([OCUnitTestRunner class], testSettings);

  // Xcode.app always passes these...
  assertThat([runner testArgumentsWithSpecifiedTestsToRun],
             containsArray(@[@"-NSTreatUnknownArgumentsAsOpen",
                               @"NO",
                               @"-ApplePersistenceIgnoreState",
                               @"YES",
                               ]));
}

- (void)testCorrectTestSpecifierArgumentsAreUsedForSenTestingKit
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"OSX-Logic-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-Library-OSXTests"];

  OCUnitTestRunner *runner = TestRunner([OCUnitIOSAppTestRunner class], testSettings);

  assertThat([runner testArgumentsWithSpecifiedTestsToRun], containsArray(@[@"-SenTest"]));
  assertThat([runner testArgumentsWithSpecifiedTestsToRun], containsArray(@[@"-SenTestInvertScope"]));
}

- (void)testCorrectTestSpecifierArgumentsAreUsedForXCTest
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"TestProject-Library-XCTest-OSX-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-Library-XCTest-OSXTests"];

  OCUnitTestRunner *runner = TestRunner([OCUnitTestRunner class], testSettings);
  assertThat([runner testArgumentsWithSpecifiedTestsToRun], containsArray(@[@"-XCTest"]));
  assertThat([runner testArgumentsWithSpecifiedTestsToRun], containsArray(@[@"-XCTestInvertScope"]));
}

- (void)testTestSpecifierIsSelfWhenRunningAllTestsInLogicTestBundle
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"OSX-Logic-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-Library-OSXTests"];

  OCUnitTestRunner *runner = TestRunnerWithTestList([OCUnitTestRunner class], testSettings, @[@"Cls1/testA", @"Cls2/testB"]);

  assertThat([runner testArgumentsWithSpecifiedTestsToRun], containsArray(@[@"-SenTest", @""]));
  assertThat([runner testArgumentsWithSpecifiedTestsToRun], containsArray(@[@"-SenTestInvertScope", @"YES"]));
}

- (void)testTestSpecifierIsAllWhenRunningAllTestsInApplicationTestBundle
{
  NSDictionary *testSettings = @{Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/"),
                                 Xcode_FULL_PRODUCT_NAME : @"TestProject-App-OSXTests.octest",
                                 Xcode_SDK_NAME : GetAvailableSDKsAndAliases()[@"macosx"],
                                 Xcode_TEST_HOST : AbsolutePathFromRelative(TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX"),
                                  };

  OCUnitTestRunner *runner = TestRunnerWithTestList([OCUnitTestRunner class], testSettings, @[@"Cls1/testA", @"Cls2/testB"]);

  assertThat([runner testArgumentsWithSpecifiedTestsToRun], containsArray(@[@"-SenTest", @"All"]));
  assertThat([runner testArgumentsWithSpecifiedTestsToRun], containsArray(@[@"-SenTestInvertScope", @"NO"]));
}

- (void)testTestSpecifierIsInvertedTestListWhenRunningSpecificTests
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"OSX-Logic-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-Library-OSXTests"];

  OCUnitTestRunner *runner = TestRunnerWithTestLists([OCUnitTestRunner class],
                                                     testSettings,
                                                     @[@"Cls1/testA"],
                                                     @[@"Cls1/testA", @"Cls2/testB"]);
  assertThat([runner testArgumentsWithSpecifiedTestsToRun], containsArray(@[@"-OTEST_TESTLIST_FILE"]));
  assertThat([runner testArgumentsWithSpecifiedTestsToRun], containsArray(@[@"-OTEST_FILTER_TEST_ARGS_KEY", @"SenTest"]));
  assertThat([runner testArgumentsWithSpecifiedTestsToRun], containsArray(@[@"-SenTestInvertScope", @"YES"]));

  NSString *testListFilePath = [runner testArgumentsWithSpecifiedTestsToRun][([[runner testArgumentsWithSpecifiedTestsToRun] indexOfObject:@"-OTEST_TESTLIST_FILE"] + 1)];
  NSString *testList = [NSString stringWithContentsOfFile:testListFilePath encoding:NSUTF8StringEncoding error:nil];
  assertThat(testList, equalTo(@"Cls2/testB"));
}

#pragma mark Tests crashing

- (void)testRunnerIsRunningAllTestsEvenIfCrashed
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"iOS-TestsThatCrash-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestsThatCrashTests"];

  NSString *outputLinesString = [NSString stringWithContentsOfFile:TEST_DATA @"iOS-TestsThatCrash-outputLines.txt"
                                                          encoding:NSUTF8StringEncoding
                                                             error:nil];
  NSArray *outputLines = [outputLinesString componentsSeparatedByString:@"\n"];

  FakeOCUnitTestRunner *runner = TestRunnerWithTestList([FakeOCUnitTestRunner class],
                                                        testSettings,
                                                        @[@"TestsThatCrashTests/testExample1",
                                                          @"TestsThatCrashTests/testExample2Fails",
                                                          @"TestsThatCrashTests/testExample3",
                                                          @"TestsThatCrashTests/testExample4Crashes",
                                                          @"TestsThatCrashTests/testExample5",
                                                          @"TestsThatCrashTests/testExample6",
                                                          @"TestsThatCrashTests/testExample7",
                                                          @"TestsThatCrashTests/testExample8"]);
  [runner setOutputLines:outputLines];
  [runner runTests];

  EventBuffer *eventBuffer = runner.reporters[0];
  NSArray *events = [eventBuffer events];

  // check number of events
  assertThatInteger([events count], equalToInteger(20));

  // check last event statistics
  assertThat([events lastObject][@"event"], equalTo(kReporter_Events_EndTestSuite));
  assertThat([events lastObject][kReporter_EndTestSuite_SuiteKey], equalTo(@"Toplevel Test Suite"));
  assertThat([events lastObject][kReporter_EndTestSuite_TestCaseCountKey], equalToInteger(8));
  assertThat([events lastObject][kReporter_EndTestSuite_TotalFailureCountKey], equalToInteger(1));
  assertThat([events lastObject][kReporter_EndTestSuite_UnexpectedExceptionCountKey], equalToInteger(1));

  // check number of begin and end events
  assertThatInteger(NumberOfEntries([events valueForKeyPath:@"event"], kReporter_Events_BeginTestSuite), equalToInteger(1));
  assertThatInteger(NumberOfEntries([events valueForKeyPath:@"event"], kReporter_Events_BeginTest), equalToInteger(8));
  assertThatInteger(NumberOfEntries([events valueForKeyPath:@"event"], kReporter_Events_EndTest), equalToInteger(8));
  assertThatInteger(NumberOfEntries([events valueForKeyPath:@"event"], kReporter_Events_EndTestSuite), equalToInteger(1));

  // check test results
  assertThatInteger(NumberOfEntries([events valueForKeyPath:kReporter_EndTest_ResultKey], @"success"), equalToInteger(6));
  assertThatInteger(NumberOfEntries([events valueForKeyPath:kReporter_EndTest_ResultKey], @"failure"), equalToInteger(1));
  assertThatInteger(NumberOfEntries([events valueForKeyPath:kReporter_EndTest_ResultKey], @"error"), equalToInteger(1));

  // check test output of crash
  assertThatInteger(NumberOfEntries([events valueForKeyPath:@"event"], kReporter_Events_TestOuput), equalToInteger(2));
  assertThat(events[8][kReporter_EndTest_OutputKey], equalTo(@"Hello!\n"));
  assertThat(events[9][kReporter_EndTest_OutputKey], equalTo(@"Test crashed while running."));
  assertThat(events[10][kReporter_EndTest_OutputKey], equalTo(@"Hello!\nTest crashed while running."));
}

#pragma mark misc.

/// otest-query returns a list of all classes. This tests the post-filtering of
/// that list to only contain specified tests.
- (void)testClassNameDiscoveryFiltering
{
  NSArray *testCases = @[
    @"Cls1/test1",
    @"Cls1/test2",
    @"Cls1/test3",
    @"Cls2/test1",
    @"Cls2/test2",
    @"Cls3/test1",
    @"OtherClass1/test1",
    @"OtherClass2/test1",
    @"OtherClass2/test2",
    @"OtherNonmatching/testOne",
    @"OtherNonmatching/testThree",
    @"OtherNonmatching/testTwo",
  ];
  NSString *error = nil;
  NSArray *onlyTestCases = nil;
  NSArray *skipTestCases = nil;

  // all test cases
  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:nil skippedTestCases:nil error:&error], equalTo(testCases));
  assertThat(error, nilValue());

  // no test cases, skip all
  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:nil skippedTestCases:testCases error:&error], equalTo(@[]));
  assertThat(error, nilValue());

  // skip specified test cases
  skipTestCases = @[
    @"Cls2/test1",
    @"Cls2/test2",
    @"Cls3/test1",
    @"OtherClass1/test1",
    @"OtherClass2/test1",
    @"OtherClass2/test2",
    @"OtherNonmatching/testOne",
    @"OtherNonmatching/testThree",
    @"OtherNonmatching/testTwo",
  ];
  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:nil skippedTestCases:skipTestCases error:&error], equalTo(@[
    @"Cls1/test1",
    @"Cls1/test2",
    @"Cls1/test3",
  ]));
  assertThat(error, nilValue());

  // skip specified class and test cases
  skipTestCases = @[
    @"Cls1",
    @"Cls2/test1",
    @"Cls3",
  ];
  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:nil skippedTestCases:skipTestCases error:&error], equalTo(@[
    @"Cls2/test2",
    @"OtherClass1/test1",
    @"OtherClass2/test1",
    @"OtherClass2/test2",
    @"OtherNonmatching/testOne",
    @"OtherNonmatching/testThree",
    @"OtherNonmatching/testTwo",
  ]));
  assertThat(error, nilValue());

  // class prefix cases (skip)
  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:nil skippedTestCases:@[@"Other*"] error:&error], equalTo(@[
    @"Cls1/test1",
    @"Cls1/test2",
    @"Cls1/test3",
    @"Cls2/test1",
    @"Cls2/test2",
    @"Cls3/test1",
  ]));
  assertThat(error, nilValue());

  // test prefix cases (skip)
  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:nil skippedTestCases:@[@"OtherNonmatching/testT*"] error:&error], equalTo(@[
    @"Cls1/test1",
    @"Cls1/test2",
    @"Cls1/test3",
    @"Cls2/test1",
    @"Cls2/test2",
    @"Cls3/test1",
    @"OtherClass1/test1",
    @"OtherClass2/test1",
    @"OtherClass2/test2",
    @"OtherNonmatching/testOne",
  ]));
  assertThat(error, nilValue());

  // only specified class test cases
  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:@[@"Cls1"] skippedTestCases:nil error:&error], equalTo(@[
    @"Cls1/test1",
    @"Cls1/test2",
    @"Cls1/test3",
  ]));
  assertThat(error, nilValue());

  // only specified classes and test case
  onlyTestCases = @[
    @"Cls1",
    @"Cls2/test1",
    @"Cls3",
  ];
  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:onlyTestCases skippedTestCases:nil error:&error], equalTo(@[
    @"Cls1/test1",
    @"Cls1/test2",
    @"Cls1/test3",
    @"Cls2/test1",
    @"Cls3/test1"
  ]));
  assertThat(error, nilValue());

  // class prefix cases (only)
  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:@[@"Other*"] skippedTestCases:nil error:&error], equalTo(@[
    @"OtherClass1/test1",
    @"OtherClass2/test1",
    @"OtherClass2/test2",
    @"OtherNonmatching/testOne",
    @"OtherNonmatching/testThree",
    @"OtherNonmatching/testTwo",
  ]));
  assertThat(error, nilValue());

  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:@[@"Cls*"] skippedTestCases:nil error:&error], equalTo(@[
    @"Cls1/test1",
    @"Cls1/test2",
    @"Cls1/test3",
    @"Cls2/test1",
    @"Cls2/test2",
    @"Cls3/test1",
  ]));
  assertThat(error, nilValue());

  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:@[@"OtherC*"] skippedTestCases:nil error:&error], equalTo(@[
    @"OtherClass1/test1",
    @"OtherClass2/test1",
    @"OtherClass2/test2",
  ]));
  assertThat(error, nilValue());

  // test prefix cases (only)
  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:@[@"OtherClass1/test*"] skippedTestCases:nil error:&error], equalTo(@[
    @"OtherClass1/test1",
  ]));
  assertThat(error, nilValue());

  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:@[@"OtherClass2/test*"] skippedTestCases:nil error:&error], equalTo(@[
    @"OtherClass2/test1",
    @"OtherClass2/test2",
  ]));
  assertThat(error, nilValue());

  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:@[@"Cls1/t*"] skippedTestCases:nil error:&error], equalTo(@[
    @"Cls1/test1",
    @"Cls1/test2",
    @"Cls1/test3",
  ]));
  assertThat(error, nilValue());

  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:@[@"OtherNonmatching/*"] skippedTestCases:nil error:&error], equalTo(@[
    @"OtherNonmatching/testOne",
    @"OtherNonmatching/testThree",
    @"OtherNonmatching/testTwo",
  ]));
  assertThat(error, nilValue());

  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:@[@"OtherNonmatching/testO*"] skippedTestCases:nil error:&error], equalTo(@[
    @"OtherNonmatching/testOne",
  ]));
  assertThat(error, nilValue());

  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:@[@"OtherNonmatching/testT*"] skippedTestCases:nil error:&error], equalTo(@[
    @"OtherNonmatching/testThree",
    @"OtherNonmatching/testTwo",
  ]));
  assertThat(error, nilValue());

  // test only non-existing test case/class
  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:@[@"OtherClassR"] skippedTestCases:nil error:&error], nilValue());
  assertThat(error, equalTo(@"Test cases for the following test specifiers weren't found: OtherClassR."));
  error = nil;

  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:@[@"OtherClass1/testR"] skippedTestCases:nil error:&error], nilValue());
  assertThat(error, equalTo(@"Test cases for the following test specifiers weren't found: OtherClass1/testR."));
  error = nil;

  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:@[@"OtherClassR*"] skippedTestCases:nil error:&error], nilValue());
  assertThat(error, equalTo(@"Test cases for the following test specifiers weren't found: OtherClassR*."));
  error = nil;

  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:@[@"OtherClass1/testR*"] skippedTestCases:nil error:&error], nilValue());
  assertThat(error, equalTo(@"Test cases for the following test specifiers weren't found: OtherClass1/testR*."));
  error = nil;

  // test only and skip test cases at the same time
  onlyTestCases = @[
    @"Cls1",
    @"Cls2/test1",
    @"Cls3",
  ];
  skipTestCases = @[
    @"Cls1",
  ];
  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:onlyTestCases skippedTestCases:skipTestCases error:&error], equalTo(@[
    @"Cls2/test1",
    @"Cls3/test1",
  ]));
  assertThat(error, nilValue());

  onlyTestCases = @[
    @"Cls1",
    @"Cls2/test1",
  ];
  skipTestCases = @[
    @"Cls3",
  ];
  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:onlyTestCases skippedTestCases:skipTestCases error:&error], equalTo(@[
    @"Cls1/test1",
    @"Cls1/test2",
    @"Cls1/test3",
    @"Cls2/test1",
  ]));
  assertThat(error, nilValue());

  onlyTestCases = @[
    @"OtherNonmatching/test*",
  ];
  skipTestCases = @[
    @"OtherNonmatching/testT*",
  ];
  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:onlyTestCases skippedTestCases:skipTestCases error:&error], equalTo(@[
    @"OtherNonmatching/testOne",
  ]));
  assertThat(error, nilValue());

  onlyTestCases = @[
    @"OtherNonmatching/test*",
  ];
  skipTestCases = @[
    @"OtherNonmatching/test*",
  ];
  assertThat([OCUnitTestRunner filterTestCases:testCases onlyTestCases:onlyTestCases skippedTestCases:skipTestCases error:&error], equalTo(@[]));
  assertThat(error, nilValue());
}

@end
