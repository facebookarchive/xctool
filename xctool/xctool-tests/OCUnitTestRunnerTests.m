
#import <SenTestingKit/SenTestingKit.h>

#import "ContainsArray.h"
#import "DTiPhoneSimulatorRemoteClient.h"
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
#import "SimulatorLauncher.h"
#import "Swizzler.h"
#import "TestUtil.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

static id TestRunnerWithTestLists(Class cls, NSDictionary *settings, NSArray *focusedTestCases, NSArray *allTestCases)
{
  NSArray *arguments = @[@"-SomeArg", @"SomeVal"];
  NSDictionary *environment = @{@"SomeEnvKey" : @"SomeEnvValue"};

  EventBuffer *eventBuffer = [[EventBuffer alloc] init];

  return [[cls alloc] initWithBuildSettings:settings
                            focusedTestCases:focusedTestCases
                                allTestCases:allTestCases
                                   arguments:arguments
                                 environment:environment
                              freshSimulator:NO
                              resetSimulator:NO
                                freshInstall:NO
                                 testTimeout:30
                                   reporters:@[eventBuffer]];
}

static id TestRunnerWithTestList(Class cls, NSDictionary *settings, NSArray *testList)
{
  return TestRunnerWithTestLists(cls, settings, testList, testList);
}

static id TestRunner(Class cls, NSDictionary *settings)
{
  return TestRunnerWithTestLists(cls, settings, @[], @[]);
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

@interface OCUnitTestRunnerTests : SenTestCase
@end

@implementation OCUnitTestRunnerTests

#pragma mark iOS Tests

- (void)runTestsForRunner:(OCUnitTestRunner *)runner
   andReturnSessionConfig:(DTiPhoneSimulatorSessionConfig **)sessionConfig
{
  [Swizzler whileSwizzlingSelector:@selector(launchAndWaitForExit)
               forInstancesOfClass:[SimulatorLauncher class]
                         withBlock:
   ^(SimulatorLauncher *self, SEL sel) {
     // Pretend it launched and succeeded, but save the config so we can check it.
     *sessionConfig = [[self valueForKey:@"session"] sessionConfig];
     return YES;
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

  NSMutableDictionary *testSettings = [allSettings[@"TestProject-LibraryTests2"] mutableCopy];
  testSettings[@"TEST_HOST"] = TEST_DATA @"FakeApp.app/FakeApp";

  DTiPhoneSimulatorSessionConfig *config;

  OCUnitTestRunner *runner = TestRunner([OCUnitIOSAppTestRunner class], testSettings);

  [self runTestsForRunner:runner
   andReturnSessionConfig:&config];

  assertThat(config, notNilValue());
  assertThat([config simulatedApplicationLaunchArgs],
             containsArray(@[@"-SomeArg",
                             @"SomeVal",
                             ]));
  assertThat([config simulatedApplicationLaunchEnvironment][@"SomeEnvKey"],
             equalTo(@"SomeEnvValue"));
  assertThat([config simulatedApplicationLaunchEnvironment][@"OTEST_SHIM_TEST_TIMEOUT"],
             equalTo(@30));

}

- (void)testIOSApplicationTestWithBadTesthostFails
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"iOS-Application-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);

  NSMutableDictionary *testSettings = [allSettings[@"TestProject-LibraryTests2"] mutableCopy];
  testSettings[@"TEST_HOST"] = @"/var/empty/whee";

  DTiPhoneSimulatorSessionConfig *config;

  OCUnitTestRunner *runner = TestRunner([OCUnitIOSAppTestRunner class], testSettings);

  [self runTestsForRunner:runner
   andReturnSessionConfig:&config];

  assertThat(config, nilValue());

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
  [self runTestsForRunner:runner
           andReturnTasks:&launchedTasks];

  assertThatInteger([launchedTasks count], equalToInteger(1));

  assertThat([launchedTasks[0] arguments],
             containsArray(@[@"-SomeArg",
                             @"SomeVal",
                             ]));
  assertThat([launchedTasks[0] environment][@"SIMSHIM_SomeEnvKey"],
             equalTo(@"SomeEnvValue"));
  assertThat([launchedTasks[0] environment][@"SIMSHIM_OTEST_SHIM_TEST_TIMEOUT"],
             equalTo(@30));
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
             equalTo(@30));
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

  assertThat([launchedTasks[0] arguments],
             containsArray(@[@"-SomeArg",
                             @"SomeVal",
                             ]));
  assertThat([launchedTasks[0] environment][@"SomeEnvKey"],
             equalTo(@"SomeEnvValue"));
  assertThat([launchedTasks[0] environment][@"OTEST_SHIM_TEST_TIMEOUT"],
             equalTo(@30));
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
  assertThat([runner testArguments],
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

  assertThat([runner testArguments], containsArray(@[@"-SenTest"]));
  assertThat([runner testArguments], containsArray(@[@"-SenTestInvertScope"]));
}

- (void)testCorrectTestSpecifierArgumentsAreUsedForXCTest
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"TestProject-Library-XCTest-OSX-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-Library-XCTest-OSXTests"];

  OCUnitTestRunner *runner = TestRunner([OCUnitTestRunner class], testSettings);
  assertThat([runner testArguments], containsArray(@[@"-XCTest"]));
  assertThat([runner testArguments], containsArray(@[@"-XCTestInvertScope"]));
}

- (void)testTestSpecifierIsSelfWhenRunningAllTestsInLogicTestBundle
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"OSX-Logic-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-Library-OSXTests"];

  OCUnitTestRunner *runner = TestRunnerWithTestList([OCUnitTestRunner class], testSettings, @[@"Cls1/testA", @"Cls2/testB"]);

  // in Xcode 6 we are always inverting scope
  if (ToolchainIsXcode6OrBetter()) {
    assertThat([runner testArguments],
               containsArray(@[@"-SenTest",
                               @"",
                               @"-SenTestInvertScope",
                               @"YES",
                               ]));
  } else {
    assertThat([runner testArguments],
               containsArray(@[@"-SenTest",
                               @"Self",
                               @"-SenTestInvertScope",
                               @"NO",
                               ]));
  }
}

- (void)testTestSpecifierIsAllWhenRunningAllTestsInApplicationTestBundle
{
  NSDictionary *testSettings = @{Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/"),
                                 Xcode_FULL_PRODUCT_NAME : @"TestProject-App-OSXTests.octest",
                                 Xcode_SDK_NAME : GetAvailableSDKsAndAliases()[@"macosx"],
                                 Xcode_TEST_HOST : AbsolutePathFromRelative(TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX"),
                                  };

  OCUnitTestRunner *runner = TestRunnerWithTestList([OCUnitTestRunner class], testSettings, @[@"Cls1/testA", @"Cls2/testB"]);

  assertThat([runner testArguments],
             containsArray(@[@"-SenTest",
                             @"All",
                             @"-SenTestInvertScope",
                             @"NO",
                             ]));
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
  assertThat([runner testArguments],
             containsArray(@[@"-SenTest",
                             @"Cls2/testB",
                             @"-SenTestInvertScope",
                             @"YES",
                             ]));
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
                         ];

  assertThat([OCUnitTestRunner filterTestCases:testCases withSenTestList:@"All" senTestInvertScope:NO],
             equalTo(testCases));
  assertThat([OCUnitTestRunner filterTestCases:testCases withSenTestList:@"Cls1" senTestInvertScope:NO],
             equalTo(@[
                     @"Cls1/test1",
                     @"Cls1/test2",
                     @"Cls1/test3",
                     ]));
  assertThat([OCUnitTestRunner filterTestCases:testCases withSenTestList:@"Cls1" senTestInvertScope:YES],
             equalTo(@[
                     @"Cls2/test1",
                     @"Cls2/test2",
                     @"Cls3/test1",
                     ]));
  assertThat([OCUnitTestRunner filterTestCases:testCases withSenTestList:@"Cls1,Cls2/test1,Cls3" senTestInvertScope:NO],
             equalTo(@[
                     @"Cls1/test1",
                     @"Cls1/test2",
                     @"Cls1/test3",
                     @"Cls2/test1",
                     @"Cls3/test1"
                     ]));
  assertThat([OCUnitTestRunner filterTestCases:testCases withSenTestList:@"Cls1,Cls2/test1,Cls3" senTestInvertScope:YES],
             equalTo(@[
                     @"Cls2/test2",
                     ]));
}

@end
