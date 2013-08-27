
#import <SenTestingKit/SenTestingKit.h>

#import "iPhoneSimulatorRemoteClient.h"

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
     OCUnitIOSAppTestRunner *runner =
      [[[OCUnitIOSAppTestRunner alloc] initWithBuildSettings:testSettings
                                                 senTestList:@"All"
                                                   arguments:
       @[
       @"-SomeArg", @"SomeVal",
       ]
                                                 environment:
       @{
       @"SomeEnvKey" : @"SomeEnvValue",
       }
                                           garbageCollection:NO
                                              freshSimulator:NO
                                                freshInstall:NO
                                               simulatorType:nil
                                                   reporters:@[]] autorelease];
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
             equalTo(@[
                     @"-NSTreatUnknownArgumentsAsOpen",
                     @"NO",
                     @"-ApplePersistenceIgnoreState",
                     @"YES",
                     @"-SenTest",
                     @"All",
                     @"-SenTestInvertScope",
                     @"NO",
                     @"-SomeArg",
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
     OCUnitIOSLogicTestRunner *runner =
     [[[OCUnitIOSLogicTestRunner alloc] initWithBuildSettings:testSettings
                                                  senTestList:@"All"
                                                    arguments:
      @[
      @"-SomeArg", @"SomeVal",
      ]
                                                  environment:
      @{
      @"SomeEnvKey" : @"SomeEnvValue",
      }
                                            garbageCollection:NO
                                               freshSimulator:NO
                                                 freshInstall:NO
                                                simulatorType:nil
                                                    reporters:@[]] autorelease];
    NSString *error = nil;
    [runner runTestsWithError:&error];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(1));

    assertThat([launchedTasks[0] arguments],
               equalTo(@[
                       @"-NSTreatUnknownArgumentsAsOpen",
                       @"NO",
                       @"-ApplePersistenceIgnoreState",
                       @"YES",
                       @"-SenTest",
                       @"All",
                       @"-SenTestInvertScope",
                       @"NO",
                       @"-SomeArg",
                       @"SomeVal",
                       @"/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-gqcuxcsyguaqwugnnwmftlazxbyg/Build/Products/Debug-iphonesimulator/TestProject-LibraryTests.octest"
                       ]));
    assertThat([launchedTasks[0] environment][@"SomeEnvKey"],
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
    OCUnitOSXAppTestRunner *runner =
    [[[OCUnitOSXAppTestRunner alloc] initWithBuildSettings:testSettings
                                               senTestList:@"All"
                                                 arguments:
     @[
     @"-SomeArg", @"SomeVal",
     ]
                                               environment:
     @{
     @"SomeEnvKey" : @"SomeEnvValue",
     }
                                         garbageCollection:NO
                                            freshSimulator:NO
                                              freshInstall:NO
                                             simulatorType:nil
                                                 reporters:@[]] autorelease];

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
             equalTo(@[
                     @"-NSTreatUnknownArgumentsAsOpen",
                     @"NO",
                     @"-ApplePersistenceIgnoreState",
                     @"YES",
                     @"-SenTest",
                     @"All",
                     @"-SenTestInvertScope",
                     @"NO",
                     @"-SomeArg",
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
    OCUnitOSXLogicTestRunner *runner =
    [[[OCUnitOSXLogicTestRunner alloc] initWithBuildSettings:testSettings
                                                 senTestList:@"All"
                                                   arguments:
      @[
      @"-SomeArg", @"SomeVal",
      ]
                                                 environment:
      @{
      @"SomeEnvKey" : @"SomeEnvValue",
      }
                                           garbageCollection:NO
                                              freshSimulator:NO
                                                freshInstall:NO
                                               simulatorType:nil
                                                   reporters:@[]] autorelease];
    NSString *error = nil;
    [runner runTestsWithError:&error];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(1));

    assertThat([launchedTasks[0] arguments],
               equalTo(@[
                       @"-NSTreatUnknownArgumentsAsOpen",
                       @"NO",
                       @"-ApplePersistenceIgnoreState",
                       @"YES",
                       @"-SenTest",
                       @"All",
                       @"-SenTestInvertScope",
                       @"NO",
                       @"-SomeArg",
                       @"SomeVal",
                       @"/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-OSX-aodfaypehmaltxamnygangxbvudj/Build/Products/Debug/TestProject-Library-OSXTests.octest"
                       ]));
    assertThat([launchedTasks[0] environment][@"SomeEnvKey"],
               equalTo(@"SomeEnvValue"));
  }];
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

- (void)testCanReduceSenTestListToBroadestForm
{
  NSArray *allTestCases = @[
                            @"Cls1/test1",
                            @"Cls1/test2",
                            @"Cls1/test3",
                            @"Cls2/test1",
                            @"Cls2/test2",
                            @"Cls3/test1",
                            ];

  // All test cases can be expressed as "All"
  assertThat(([OCUnitTestRunner reduceSenTestListToBroadestForm:allTestCases allTestCases:allTestCases]),
             equalTo(@"All"));
  // All test cases of a specific test class (e.g. Cls2) can be expressed as just
  // the class name.
  assertThat(([OCUnitTestRunner reduceSenTestListToBroadestForm:@[
               @"Cls2/test1",
               @"Cls2/test2"]
                                                   allTestCases:allTestCases]),
             equalTo(@"Cls2"));
  // If only 1 test case in a specific class is selected, it should be expressed
  // with the full Class/method form.
  assertThat(([OCUnitTestRunner reduceSenTestListToBroadestForm:@[
               @"Cls1/test3",
               @"Cls2/test1",
               @"Cls2/test2"]
                                                   allTestCases:allTestCases]),
             equalTo(@"Cls1/test3,Cls2"));
  // No tests cases means 'None'
  assertThat(([OCUnitTestRunner reduceSenTestListToBroadestForm:@[]
                                                   allTestCases:allTestCases]),
             equalTo(@"None"));
}

@end
