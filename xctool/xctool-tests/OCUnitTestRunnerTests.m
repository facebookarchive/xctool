
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


// -----------------------------------------------------------------
#pragma mark iOS Tests
// -----------------------------------------------------------------

- (void)simulateIOSApplicationTestWithSettings:(NSDictionary*)testSettings
                                     putConfig:(DTiPhoneSimulatorSessionConfig**)configptr
                                      putError:(NSString**)errptr
{
  *configptr = nil;
  *errptr = nil;

  [Swizzler whileSwizzlingSelector:@selector(launchAndWaitForExit)
               forInstancesOfClass:[SimulatorLauncher class]
                         withBlock:
   ^(SimulatorLauncher *self, SEL sel) {
     // Pretend it launched and succeeded, but save the config so we can check it.
     *configptr = [[self->_session sessionConfig] retain];
     return YES;
   }
                          runBlock:
   ^{
     OCUnitIOSAppTestRunner *runner =
      [[[OCUnitIOSAppTestRunner alloc] initWithBuildSettings:testSettings
                                                 senTestList:@"All"
                                          senTestInvertScope:NO
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
                                              standardOutput:[NSFileHandle fileHandleWithNullDevice]
                                               standardError:[NSFileHandle fileHandleWithNullDevice]
                                                   reporters:@[]] autorelease];
     [runner runTestsWithError:errptr];
   }];
}

- (void)testArgsAndEnvArePassedToIOSApplicationTest
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"iOS-Application-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);

  NSMutableDictionary *testSettings = [allSettings[@"TestProject-LibraryTests2"] mutableCopy];
  testSettings[@"TEST_HOST"] = TEST_DATA @"FakeApp.fakeapp/FakeAppExe";

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
                                           senTestInvertScope:NO
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
                                               standardOutput:[NSFileHandle fileHandleWithNullDevice]
                                                standardError:[NSFileHandle fileHandleWithNullDevice]
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


// -----------------------------------------------------------------
#pragma mark OSX Tests
// -----------------------------------------------------------------

- (void)simulateOSXApplicationTestWithSettings:(NSDictionary*)testSettings
                                      putTasks:(NSArray**)tasksptr
                                      putError:(NSString**)errptr
{
  *tasksptr = nil;
  *errptr = nil;

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    OCUnitOSXAppTestRunner *runner =
    [[[OCUnitOSXAppTestRunner alloc] initWithBuildSettings:testSettings
                                               senTestList:@"All"
                                        senTestInvertScope:NO
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
                                            standardOutput:[NSFileHandle fileHandleWithNullDevice]
                                             standardError:[NSFileHandle fileHandleWithNullDevice]
                                                 reporters:@[]] autorelease];

    [runner runTestsWithError:errptr];

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
  testSettings[@"TEST_HOST"] = TEST_DATA @"FakeApp.fakeapp/FakeAppExe";

  NSArray *launchedTasks;
  NSString *err;

  [self simulateOSXApplicationTestWithSettings:testSettings putTasks:&launchedTasks putError:&err];

  assertThatInteger([launchedTasks count], equalToInteger(1));
  if ([launchedTasks count] == 0)
    return; // Avoid NSRangeException => continue to other tests in file
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
                                          senTestInvertScope:NO
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
                                              standardOutput:[NSFileHandle fileHandleWithNullDevice]
                                               standardError:[NSFileHandle fileHandleWithNullDevice]
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


// -----------------------------------------------------------------
#pragma mark misc.
// -----------------------------------------------------------------

/// otest-query returns a list of all classes. This tests the post-filtering of
/// that list to only contain specified tests.
- (void)testClassNameDiscoveryFiltering
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"OSX-Application-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-App-OSXTests"];

  OCUnitIOSLogicTestRunner *(^makeTestRunner)(NSString *, BOOL) =
  ^(NSString *senTestList, BOOL senTestInvertScope) {
    return [[[OCUnitIOSLogicTestRunner alloc]
             initWithBuildSettings:testSettings
             senTestList:senTestList
             senTestInvertScope:senTestInvertScope
             arguments:@[]
             environment:@{}
             garbageCollection:NO
             freshSimulator:NO
             freshInstall:NO
             simulatorType:nil
             standardOutput:[NSFileHandle fileHandleWithNullDevice]
             standardError:[NSFileHandle fileHandleWithNullDevice]
             reporters:@[]] autorelease];
  };

  [Swizzler whileSwizzlingSelector:@selector(runTestClassListQuery)
               forInstancesOfClass:[OCUnitIOSLogicTestRunner class]
                         withBlock:^() { return @[@"A", @"B", @"C"]; }
                          runBlock:
   ^() {
     assertThat([makeTestRunner(@"All", NO) testClassNames],
                equalTo(@[@"A", @"B", @"C"]));
     assertThat([makeTestRunner(@"A", NO) testClassNames],
                equalTo(@[@"A"]));
     assertThat([makeTestRunner(@"A", YES) testClassNames],
                equalTo(@[@"B", @"C"]));
     assertThat([makeTestRunner(@"A,B", NO) testClassNames],
                equalTo(@[@"A", @"B"]));
     assertThat([makeTestRunner(@"A,B", YES) testClassNames],
                equalTo(@[@"C"]));
   }];
}

@end
