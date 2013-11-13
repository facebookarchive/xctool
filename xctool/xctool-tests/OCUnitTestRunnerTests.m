
#import <SenTestingKit/SenTestingKit.h>

#import "iPhoneSimulatorRemoteClient.h"

#import "ContainsArray.h"
#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "OCUnitTestRunner.h"
#import "OCUnitOSXAppTestRunner.h"
#import "OCUnitOSXLogicTestRunner.h"
#import "OCUnitIOSAppTestRunner.h"
#import "OCUnitIOSLogicTestRunner.h"
#import "SimulatorLauncher.h"
#import "Swizzler.h"
#import "XCToolUtil.h"

static OCUnitTestRunner *TestRunnerWithTestLists(Class cls, NSDictionary *settings, NSArray *focusedTestCases, NSArray *allTestCases)
{
  NSArray *arguments = @[@"-SomeArg", @"SomeVal"];
  NSDictionary *environment = @{@"SomeEnvKey" : @"SomeEnvValue"};

  return [[[cls alloc] initWithBuildSettings:settings
                            focusedTestCases:focusedTestCases
                                allTestCases:allTestCases
                                   arguments:arguments
                                 environment:environment
                           garbageCollection:NO
                              freshSimulator:NO
                                freshInstall:NO
                               simulatorType:nil
                                   reporters:@[]] autorelease];
}

static OCUnitTestRunner *TestRunnerWithTestList(Class cls, NSDictionary *settings, NSArray *testList)
{
  return TestRunnerWithTestLists(cls, settings, testList, testList);
}

static OCUnitTestRunner *TestRunner(Class cls, NSDictionary *settings)
{
  return TestRunnerWithTestLists(cls, settings, @[], @[]);
}


@interface OCUnitTestRunnerTests : SenTestCase
@end

@implementation OCUnitTestRunnerTests

#pragma mark iOS Tests

- (void)simulateIOSApplicationTestWithSettings:(NSDictionary*)testSettings
                                     putConfig:(DTiPhoneSimulatorSessionConfig**)configPtr
                                      putError:(NSString**)errPtr
{
  *configPtr = nil;
  *errPtr = nil;

  [Swizzler whileSwizzlingSelector:@selector(launchAndWaitForExit)
               forInstancesOfClass:[SimulatorLauncher class]
                         withBlock:
   ^(SimulatorLauncher *self, SEL sel) {
     // Pretend it launched and succeeded, but save the config so we can check it.
     *configPtr = [[self->_session sessionConfig] retain];
     return YES;
   }
                          runBlock:
   ^{
     OCUnitTestRunner *runner = TestRunner([OCUnitIOSAppTestRunner class], testSettings);
     [runner runTestsWithError:errPtr];
   }];
}

- (void)testArgsAndEnvArePassedToIOSApplicationTest
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"iOS-Application-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);

  NSMutableDictionary *testSettings = [allSettings[@"TestProject-LibraryTests2"] mutableCopy];
  testSettings[@"TEST_HOST"] = TEST_DATA @"FakeApp.app/FakeAppExe";

  DTiPhoneSimulatorSessionConfig *config;
  NSString *err;

  [self simulateIOSApplicationTestWithSettings:testSettings putConfig:&config putError:&err];

  assertThat(config, notNilValue());
  assertThat([config simulatedApplicationLaunchArgs],
             containsArray(@[@"-SomeArg",
                             @"SomeVal",
                             ]));
  assertThat([config simulatedApplicationLaunchEnvironment][@"SomeEnvKey"],
             equalTo(@"SomeEnvValue"));

  [config release];
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
  NSString *err;

  [self simulateIOSApplicationTestWithSettings:testSettings putConfig:&config putError:&err];

  assertThat(config, nilValue());
  assertThat(err, containsString(@"TEST_HOST"));

  [config release];
}

- (void)testArgsAndEnvArePassedToIOSLogicTest
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"iOS-Logic-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-LibraryTests"];

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    OCUnitTestRunner *runner = TestRunner([OCUnitIOSLogicTestRunner class], testSettings);

    NSString *error = nil;
    [runner runTestsWithError:&error];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(1));

    assertThat([launchedTasks[0] arguments],
               containsArray(@[@"-SomeArg",
                               @"SomeVal",
                               ]));
    assertThat([launchedTasks[0] environment][@"SIMSHIM_SomeEnvKey"],
               equalTo(@"SomeEnvValue"));
  }];
}

#pragma mark OSX Tests

- (void)simulateOSXApplicationTestWithSettings:(NSDictionary*)testSettings
                                      putTasks:(NSArray**)tasksptr
                                      putError:(NSString**)errPtr
{
  *tasksptr = nil;
  *errPtr = nil;

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    OCUnitTestRunner *runner = TestRunner([OCUnitOSXAppTestRunner class], testSettings);
    [runner runTestsWithError:errPtr];

    *tasksptr = [[[FakeTaskManager sharedManager] launchedTasks] retain];
  }];
}

- (void)testArgsAndEnvArePassedToOSXApplicationTest
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"OSX-Application-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);

  NSMutableDictionary *testSettings = [allSettings[@"TestProject-App-OSXTests"] mutableCopy];
  testSettings[@"TEST_HOST"] = TEST_DATA @"FakeApp.app/FakeAppExe";

  NSArray *launchedTasks;
  NSString *err;

  [self simulateOSXApplicationTestWithSettings:testSettings putTasks:&launchedTasks putError:&err];

  assertThatInteger([launchedTasks count], equalToInteger(1));
  assertThat([launchedTasks[0] arguments],
             containsArray(@[@"-SomeArg",
                             @"SomeVal",
                             ]));
  assertThat([launchedTasks[0] environment][@"SomeEnvKey"],
             equalTo(@"SomeEnvValue"));
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
  NSString *err;

  [self simulateOSXApplicationTestWithSettings:testSettings putTasks:&launchedTasks putError:&err];

  assertThatInteger([launchedTasks count], equalToInteger(0));
  assertThat(err, containsString(@"TEST_HOST"));
}


- (void)testArgsAndEnvArePassedToOSXLogicTest
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"OSX-Logic-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-Library-OSXTests"];

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    OCUnitTestRunner *runner = TestRunner([OCUnitOSXLogicTestRunner class], testSettings);

    NSString *error = nil;
    [runner runTestsWithError:&error];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(1));

    assertThat([launchedTasks[0] arguments],
               containsArray(@[@"-SomeArg",
                               @"SomeVal",
                               ]));
    assertThat([launchedTasks[0] environment][@"SomeEnvKey"],
               equalTo(@"SomeEnvValue"));
  }];
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

  assertThat([runner testArguments],
             containsArray(@[@"-SenTest",
                             @"Self",
                             @"-SenTestInvertScope",
                             @"NO",
                             ]));
}

- (void)testTestSpecifierIsAllWhenRunningAllTestsInApplicationTestBundle
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"OSX-Application-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-App-OSXTests"];

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
