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

#import "Action.h"
#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "LaunchHandlers.h"
#import "OCUnitTestRunner.h"
#import "Options.h"
#import "Options+Testing.h"
#import "RunTestsAction.h"
#import "Swizzler.h"
#import "TaskUtil.h"
#import "TestUtil.h"
#import "XCTool.h"
#import "XCToolUtil.h"
#import "XcodeSubjectInfo.h"

@interface RunTestsActionTests : SenTestCase
@end

@implementation RunTestsActionTests

- (void)setUp
{
  [super setUp];
}

- (void)testTestSDKIsCollected
{
  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator6.1",
                       @"run-tests", @"-test-sdk", @"iphonesimulator6.0"
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  RunTestsAction *action = options.actions[0];
  assertThat((action.testSDK), equalTo(@"iphonesimulator6.0"));
}

- (void)testOnlyListIsCollected
{
  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator6.1",
                       @"run-tests", @"-only", @"TestProject-LibraryTests",
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  RunTestsAction *action = options.actions[0];
  assertThat((action.onlyList), equalTo(@[@"TestProject-LibraryTests"]));
}

- (void)testOnlyListRequiresValidTarget
{
  [[Options optionsFrom:@[
    @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
    @"-scheme", @"TestProject-Library",
    @"-sdk", @"iphonesimulator6.1",
    @"run-tests", @"-only", @"BOGUS_TARGET",
    ]]
   assertOptionsFailToValidateWithError:
   @"run-tests: 'BOGUS_TARGET' is not a testing target in this scheme."
   withBuildSettingsFromFile:
   TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
   ];
}

- (void)testWithSDKsDefaultsToValueOfSDKIfNotSupplied
{
  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator6.1",
                       @"run-tests",
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  RunTestsAction *action = options.actions[0];
  assertThat(action.testSDK, equalTo(@"iphonesimulator6.1"));
}

- (void)testRunTestsFailsWhenSDKIsIPHONEOS
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"
                                                     scheme:@"TestProject-Library"
                                               settingsPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"],
     // We're going to call -showBuildSettings on the test target.
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"
                                                     target:@"TestProject-LibraryTests"
                                               settingsPath:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-showBuildSettings-iphoneos.txt"
                                                       hide:NO],
     [LaunchHandlers handlerForOtestQueryReturningTestList:@[]],
     ]];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Debug",
                       @"run-tests"
                       ];

    NSDictionary *output = [TestUtil runWithFakeStreams:tool];

    assertThatInt(tool.exitStatus, equalToInt(1));
    assertThat(output[@"stdout"],
               containsString(@"Testing with the 'iphoneos' SDK is not yet supported.  "
                              @"Instead, test with the simulator SDK by setting '-sdk iphonesimulator'.\n"));
  }];
}

- (void)testRunTestsAction
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"
                                                     scheme:@"TestProject-Library"
                                               settingsPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"],
     // We're going to call -showBuildSettings on the test target.
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"
                                                     target:@"TestProject-LibraryTests"
                                               settingsPath:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-showBuildSettings.txt"
                                                       hide:NO],
     [LaunchHandlers handlerForOtestQueryReturningTestList:@[@"TestA", @"TestB"]],
     [[^(FakeTask *task){
      if ([[task launchPath] hasSuffix:@"otest"]) {
        // Pretend the tests fail, which should make xctool return an overall
        // status of 1.
        [task pretendExitStatusOf:1];
        [task pretendTaskReturnsStandardOutput:
         [NSString stringWithContentsOfFile:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-test-results.txt"
                                   encoding:NSUTF8StringEncoding
                                      error:nil]];
      }
    } copy] autorelease],
     ]];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"run-tests"
                       ];

    [TestUtil runWithFakeStreams:tool];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(2));
    assertThat([launchedTasks[0] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"PLATFORM_NAME=iphonesimulator",
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-target", @"TestProject-LibraryTests",
                       @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates",
                       @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates/PrecompiledHeaders",
                       @"-showBuildSettings"
                       ]));
    assertThat([launchedTasks[1] arguments],
               equalTo(@[
                       @"-NSTreatUnknownArgumentsAsOpen", @"NO",
                       @"-ApplePersistenceIgnoreState", @"YES",
                       @"-SenTest", @"All",
                       @"-SenTestInvertScope", @"NO",
                       @"/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Products/Debug-iphonesimulator/TestProject-LibraryTests.octest",
                       ]));
    assertThatInt(tool.exitStatus, equalToInt(1));
  }];
}

- (void)testCanRunTestsAgainstDifferentTestSDK
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"
                                                     scheme:@"TestProject-Library"
                                               settingsPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"],
     // We're going to call -showBuildSettings on the test target.
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"
                                                     target:@"TestProject-LibraryTests"
                                               settingsPath:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-showBuildSettings-5.0.txt"
                                                       hide:NO],
     [LaunchHandlers handlerForOtestQueryReturningTestList:@[@"TestA", @"TestB"]],
     [[^(FakeTask *task){
      if ([[task launchPath] hasSuffix:@"otest"]) {
        // Pretend the tests fail, which should make xctool return an overall
        // status of 1.
        [task pretendExitStatusOf:1];
        [task pretendTaskReturnsStandardOutput:
         [NSString stringWithContentsOfFile:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-test-results.txt"
                                   encoding:NSUTF8StringEncoding
                                      error:nil]];
      }

    } copy] autorelease],
     ]];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"run-tests", @"-test-sdk", @"iphonesimulator5.0",
                       ];

    [TestUtil runWithFakeStreams:tool];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(2));
    assertThat([launchedTasks[0] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator5.0",
                       @"PLATFORM_NAME=iphonesimulator",
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-target", @"TestProject-LibraryTests",
                       @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates",
                       @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates/PrecompiledHeaders",
                       @"-showBuildSettings"
                       ]));
    assertThat([launchedTasks[1] arguments],
               equalTo(@[
                       @"-NSTreatUnknownArgumentsAsOpen", @"NO",
                       @"-ApplePersistenceIgnoreState", @"YES",
                       @"-SenTest", @"All",
                       @"-SenTestInvertScope", @"NO",
                       @"/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Products/Debug-iphonesimulator/TestProject-LibraryTests.octest",
                       ]));
    // Since we're targetting the 5.0, the environment should be different.
    assertThat([launchedTasks[1] environment][@"DYLD_ROOT_PATH"],
               equalTo(@"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.0.sdk"));
    assertThatInt(tool.exitStatus, equalToInt(1));
  }];
}

- (void)testCanSelectSpecificTestClassOrTestMethodWithOnly
{
  void (^runWithOnlyArgumentAndExpectSenTestToBe)(NSString *, NSString *) = ^(NSString *onlyArgument, NSString *expectedSenTest) {
    [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
                                                                // Make sure -showBuildSettings returns some data
                                                                [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"
                                                                                                                scheme:@"TestProject-Library"
                                                                                                          settingsPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"],
                                                                // We're going to call -showBuildSettings on the test target.
                                                                [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"
                                                                                                                target:@"TestProject-LibraryTests"
                                                                                                          settingsPath:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-showBuildSettings-5.0.txt"
                                                                                                                  hide:NO],
                                                                [LaunchHandlers handlerForOtestQueryReturningTestList:@[
                                                                                                                        @"OtherTests/testSomething",
                                                                                                                        @"SomeTests/testWillFail",
                                                                                                                        @"SomeTests/testWillPass",
                                                                                                                        ]],
                                                                [[^(FakeTask *task){
        if ([[task launchPath] hasSuffix:@"otest"]) {
          [task pretendTaskReturnsStandardOutput:
           [NSString stringWithContentsOfFile:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-test-results.txt"
                                     encoding:NSUTF8StringEncoding
                                        error:nil]];
        }

      } copy] autorelease],
                                                                ]];

      XCTool *tool = [[[XCTool alloc] init] autorelease];

      tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                         @"-scheme", @"TestProject-Library",
                         @"-configuration", @"Debug",
                         @"-sdk", @"iphonesimulator6.0",
                         @"run-tests", @"-only", onlyArgument,
                         ];

      [TestUtil runWithFakeStreams:tool];

      NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
      assertThatInteger([launchedTasks count], equalToInteger(2));
      assertThat([launchedTasks[1] arguments],
                 equalTo(@[
                           @"-NSTreatUnknownArgumentsAsOpen", @"NO",
                           @"-ApplePersistenceIgnoreState", @"YES",
                           @"-SenTest", expectedSenTest,
                           @"-SenTestInvertScope", @"NO",
                           @"/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Products/Debug-iphonesimulator/TestProject-LibraryTests.octest",
                           ]));
    }];
  };

  runWithOnlyArgumentAndExpectSenTestToBe(@"TestProject-LibraryTests:SomeTests", @"SomeTests");
  runWithOnlyArgumentAndExpectSenTestToBe(@"TestProject-LibraryTests:SomeTests/testWillPass", @"SomeTests/testWillPass");
  runWithOnlyArgumentAndExpectSenTestToBe(@"TestProject-LibraryTests:SomeTests/testWillPass,OtherTests/testSomething",
                                          // Since OtherTests has only 1 test, it will get reduced to just the test name.
                                          // And, the ordering will be alphabetized.
                                          @"OtherTests,SomeTests/testWillPass");
}

/**
 By default, Xcode will run your tests with whatever extra args or environment
 settings you've configured for your Run action in the scheme editor.
 */
- (void)testSchemeArgsAndEnvForRunActionArePassedToTestRunner
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestsWithArgAndEnvSettingsInRunAction/TestsWithArgAndEnvSettings.xcodeproj"
                                                     scheme:@"TestsWithArgAndEnvSettings"
                                               settingsPath:TEST_DATA @"TestsWithArgAndEnvSettingsInRunAction-TestsWithArgAndEnvSettings-showBuildSettings.txt"],
     // We're going to call -showBuildSettings on the test target.
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestsWithArgAndEnvSettingsInRunAction/TestsWithArgAndEnvSettings.xcodeproj"
                                                     target:@"TestsWithArgAndEnvSettingsTests"
                                               settingsPath:TEST_DATA @"TestsWithArgAndEnvSettingsInRunAction-TestsWithArgAndEnvSettings-TestsWithArgAndEnvSettingsTests-showBuildSettings.txt"
                                                       hide:NO],
     [LaunchHandlers handlerForOtestQueryReturningTestList:@[@"TestA", @"TestB"]],
     ]];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[@"-project", TEST_DATA @"TestsWithArgAndEnvSettingsInRunAction/TestsWithArgAndEnvSettings.xcodeproj",
                       @"-scheme", @"TestsWithArgAndEnvSettings",
                       @"run-tests",
                       ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTestsWithError:)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = [self retain];
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       assertThat(runner, notNilValue());
       assertThat(runner->_arguments,
                  equalTo(@[@"-RunArg", @"RunArgValue"]));
       assertThat(runner->_environment,
                  equalTo(@{@"RunEnvKey" : @"RunEnvValue"}));
     }];

    [runner release];
  }];
}

/**
 Optionally, Xcode can also run your tests with specific args or environment
 vars that you've configured for your Test action in the scheme editor.
 */
- (void)testSchemeArgsAndEnvForTestActionArePassedToTestRunner
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestsWithArgAndEnvSettingsInTestAction/TestsWithArgAndEnvSettings.xcodeproj"
                                                     scheme:@"TestsWithArgAndEnvSettings"
                                               settingsPath:TEST_DATA @"TestsWithArgAndEnvSettingsInTestAction-TestsWithArgAndEnvSettings-showBuildSettings.txt"],
     // We're going to call -showBuildSettings on the test target.
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestsWithArgAndEnvSettingsInTestAction/TestsWithArgAndEnvSettings.xcodeproj"
                                                     target:@"TestsWithArgAndEnvSettingsTests"
                                               settingsPath:TEST_DATA @"TestsWithArgAndEnvSettingsInTestAction-TestsWithArgAndEnvSettings-TestsWithArgAndEnvSettingsTests-showBuildSettings.txt"
                                                       hide:NO],
     [LaunchHandlers handlerForOtestQueryReturningTestList:@[@"TestA", @"TestB"]],
     ]];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[@"-project", TEST_DATA @"TestsWithArgAndEnvSettingsInTestAction/TestsWithArgAndEnvSettings.xcodeproj",
                       @"-scheme", @"TestsWithArgAndEnvSettings",
                       @"run-tests",
                       ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTestsWithError:)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = [self retain];
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       assertThat(runner, notNilValue());
       assertThat(runner->_arguments,
                  equalTo(@[@"-TestArg", @"TestArgValue"]));
       assertThat(runner->_environment,
                  equalTo(@{@"TestEnvKey" : @"TestEnvValue"}));
     }];

    [runner release];
  }];
}

/**
 Xcode will let you use macros like $(SOMEVAR) in the arguments or environment
 variables specified in your scheme.
 */
- (void)testSchemeArgsAndEnvCanUseMacroExpansion
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestsWithArgAndEnvSettingsWithMacroExpansion/TestsWithArgAndEnvSettings.xcodeproj"
                                                     scheme:@"TestsWithArgAndEnvSettings"
                                               settingsPath:TEST_DATA @"TestsWithArgAndEnvSettingsWithMacroExpansion-TestsWithArgAndEnvSettings-showBuildSettings.txt"],
     // We're going to call -showBuildSettings on the test target.
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestsWithArgAndEnvSettingsWithMacroExpansion/TestsWithArgAndEnvSettings.xcodeproj"
                                                     target:@"TestsWithArgAndEnvSettingsTests"
                                               settingsPath:TEST_DATA @"TestsWithArgAndEnvSettingsWithMacroExpansion-TestsWithArgAndEnvSettings-TestsWithArgAndEnvSettingsTests-showBuildSettings.txt"
                                                       hide:NO],
     [LaunchHandlers handlerForOtestQueryReturningTestList:@[@"TestA", @"TestB"]],
     ]];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[@"-project", TEST_DATA @"TestsWithArgAndEnvSettingsWithMacroExpansion/TestsWithArgAndEnvSettings.xcodeproj",
                       @"-scheme", @"TestsWithArgAndEnvSettings",
                       @"run-tests",
                       ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTestsWithError:)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = [self retain];
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       assertThat(runner, notNilValue());
       assertThat(runner->_arguments,
                  equalTo(@[]));
       assertThat(runner->_environment,
                  equalTo(@{
                          @"RunEnvKey" : @"RunEnvValue",
                          @"ARCHS" : @"x86_64",
                          @"DYLD_INSERT_LIBRARIES" : @"ThisShouldNotGetOverwrittenByOtestShim",
                          }));


       NSMutableDictionary *expectedEnv = [NSMutableDictionary dictionary];
       [expectedEnv addEntriesFromDictionary:[[NSProcessInfo processInfo] environment]];
       expectedEnv[@"DYLD_INSERT_LIBRARIES"] = @"ThisShouldNotGetOverwrittenByOtestShim:/pretend/this/is/otest-shim.dylib";
       expectedEnv[@"RunEnvKey"] = @"RunEnvValue";
       expectedEnv[@"ARCHS"] = @"x86_64";

       assertThat([runner otestEnvironmentWithOverrides:@{
                   @"DYLD_INSERT_LIBRARIES" : @"/pretend/this/is/otest-shim.dylib"}],
                  equalTo(expectedEnv));
     }];

    [runner release];
  }];
}

- (void)testConfigurationIsTakenFromScheme
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj"
                                                     scheme:@"TestProject-Library"
                                               settingsPath:TEST_DATA @"TestProject-Library-WithDifferentConfigurations-showBuildSettings.txt"],
     // We're going to call -showBuildSettings on the test target.
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj"
                                                     target:@"TestProject-LibraryTests"
                                               settingsPath:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-showBuildSettings-5.0.txt"
                                                       hide:NO],
     [LaunchHandlers handlerForOtestQueryReturningTestList:@[@"TestA", @"TestB"]],
     ]];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator",
                       @"-arch", @"i386",
                       @"run-tests",
                       ];

    [TestUtil runWithFakeStreams:tool];

    assertThat([[[FakeTaskManager sharedManager] launchedTasks][0] arguments],
               equalTo(@[
                       @"-configuration",
                       @"TestConfig",
                       @"-sdk",
                       @"iphonesimulator6.1",
                       @"-arch",
                       @"i386",
                       @"PLATFORM_NAME=iphonesimulator",
                       @"-project",
                       @"xctool-tests/TestData/TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj",
                       @"-target",
                       @"TestProject-LibraryTests",
                       @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-dcmgtqlclwxdzqevoakcspwlrpfm/Build/Intermediates",
                       @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-dcmgtqlclwxdzqevoakcspwlrpfm/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-dcmgtqlclwxdzqevoakcspwlrpfm/Build/Intermediates/PrecompiledHeaders",
                       @"-showBuildSettings"
                       ]));
  }];
}

- (void)testCanBucketizeTestCasesByTestCase
{
  assertThat(BucketizeTestCasesByTestCase(@[
                                            @"Cls1/test1",
                                            @"Cls1/test2",
                                            @"Cls2/test1",
                                            @"Cls2/test2",
                                            @"Cls3/test1",
                                            @"Cls3/test2",
                                            @"Cls3/test3",
                                            ], 3),
             equalTo(@[
                       @[
                         @"Cls1/test1",
                         @"Cls1/test2",
                         @"Cls2/test1",
                         ],
                       @[
                         @"Cls2/test2",
                         @"Cls3/test1",
                         @"Cls3/test2",
                         ],
                       @[
                         @"Cls3/test3"
                         ],
                       ]));
}

- (void)testCanBucketizeTestCasesByTestClass
{
  assertThat(BucketizeTestCasesByTestClass(@[
                                            @"Cls1/test1",
                                            @"Cls1/test2",
                                            @"Cls2/test1",
                                            @"Cls2/test2",
                                            @"Cls3/test1",
                                            @"Cls3/test2",
                                            @"Cls3/test3",
                                            @"Cls4/test1",
                                            @"Cls5/test1",
                                            @"Cls6/test1",
                                            @"Cls7/test1",
                                            ], 3),
             equalTo(@[
                       @[
                         @"Cls1/test1",
                         @"Cls1/test2",
                         @"Cls2/test1",
                         @"Cls2/test2",
                         @"Cls3/test1",
                         @"Cls3/test2",
                         @"Cls3/test3"
                         ],
                       @[
                         @"Cls4/test1",
                         @"Cls5/test1",
                         @"Cls6/test1",
                         ],
                       @[
                         @"Cls7/test1",
                         ],
                       ]));
}

@end
