
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

- (void)testArgsAndEnvArePassedToIOSApplicationTest
{
  NSDictionary *allSettings =
    BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"iOS-Application-Test-showBuildSettings.txt"
                                                      encoding:NSUTF8StringEncoding
                                                         error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-LibraryTests2"];

  __block DTiPhoneSimulatorSessionConfig *config = nil;

  [Swizzler whileSwizzlingSelector:@selector(launchAndWaitForExit)
               forInstancesOfClass:[SimulatorLauncher class]
                         withBlock:
   ^(SimulatorLauncher *self, SEL sel) {
     // Pretend it launched and succeeded, but save the config so we can check it.
     config = [[self->_session sessionConfig] retain];
     return YES;
   }
                          runBlock:
   ^{
     OCUnitIOSAppTestRunner *runner =
      [[OCUnitIOSAppTestRunner alloc] initWithBuildSettings:testSettings
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
                                             standardOutput:[NSFileHandle fileHandleWithNullDevice]
                                              standardError:[NSFileHandle fileHandleWithNullDevice]
                                                  reporters:@[]];
     NSString *error = nil;
     [runner runTestsWithError:&error];
   }];

  NSArray *arguments = [config simulatedApplicationLaunchArgs];
  assertThat(arguments,
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

- (void)testArgsAndEnvArePassedToIOSLogicTest
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"iOS-Logic-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-LibraryTests"];

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
     OCUnitIOSLogicTestRunner *runner =
     [[OCUnitIOSLogicTestRunner alloc] initWithBuildSettings:testSettings
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
                                            standardOutput:[NSFileHandle fileHandleWithNullDevice]
                                             standardError:[NSFileHandle fileHandleWithNullDevice]
                                                 reporters:@[]];
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

- (void)testArgsAndEnvArePassedToOSXLogicTest
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"OSX-Logic-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-Library-OSXTests"];

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    OCUnitOSXLogicTestRunner *runner =
    [[OCUnitOSXLogicTestRunner alloc] initWithBuildSettings:testSettings
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
                                             standardOutput:[NSFileHandle fileHandleWithNullDevice]
                                              standardError:[NSFileHandle fileHandleWithNullDevice]
                                                  reporters:@[]];
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

- (void)testArgsAndEnvArePassedToOSXApplicationTest
{
  NSDictionary *allSettings =
  BuildSettingsFromOutput([NSString stringWithContentsOfFile:TEST_DATA @"OSX-Application-Test-showBuildSettings.txt"
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil]);
  NSDictionary *testSettings = allSettings[@"TestProject-App-OSXTests"];

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    OCUnitOSXAppTestRunner *runner =
    [[OCUnitOSXAppTestRunner alloc] initWithBuildSettings:testSettings
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
                                             standardOutput:[NSFileHandle fileHandleWithNullDevice]
                                              standardError:[NSFileHandle fileHandleWithNullDevice]
                                                  reporters:@[]];
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
                       ]));
    assertThat([launchedTasks[0] environment][@"SomeEnvKey"],
               equalTo(@"SomeEnvValue"));
  }];
}

@end
