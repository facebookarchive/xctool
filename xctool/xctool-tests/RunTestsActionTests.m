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

#import "Action.h"
#import "ContainsArray.h"
#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "LaunchHandlers.h"
#import "OCUnitTestRunner.h"
#import "Options+Testing.h"
#import "Options.h"
#import "RunTestsAction.h"
#import "Swizzler.h"
#import "TaskUtil.h"
#import "TestUtil.h"
#import "XCTool.h"
#import "XCToolUtil.h"
#import "XcodeSubjectInfo.h"
#import "XCTestConfiguration.h"

@interface OCUnitTestRunner ()
@property (nonatomic, copy) SimulatorInfo *simulatorInfo;
@end

static BOOL areEqualJsonOutputsIgnoringKeys(NSString *output1, NSString *output2, NSArray *keys)
{
  NSArray *output1Array = [[output1 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByString:@"\n"];
  NSArray *output2Array = [[output2 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByString:@"\n"];
  if ([output1Array count] != [output2Array count]) {
    return NO;
  }

  for (int i=0; i<[output1Array count]; i++) {
    NSMutableDictionary *dict1 = [[NSJSONSerialization JSONObjectWithData:[output1Array[i] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] mutableCopy];
    NSMutableDictionary *dict2 = [[NSJSONSerialization JSONObjectWithData:[output2Array[i] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] mutableCopy];
    for (NSString *key in keys) {
      [dict1 removeObjectForKey:key];
      [dict2 removeObjectForKey:key];
    }
    if (![dict1 isEqual:dict2]) {
      return NO;
    }
  }

  return YES;
}

@interface RunTestsActionTests : XCTestCase
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

- (void)testOnlyListAndOmitListCannotBothBeSpecified
{
  [[Options optionsFrom:@[
    @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
    @"-scheme", @"TestProject-Library",
    @"-sdk", @"iphonesimulator6.1",
    @"run-tests",
    @"-only", @"TestProject-LibraryTests",
    @"-omit", @"TestProject-LibraryTests",
    ]]
   assertOptionsFailToValidateWithError:
   @"run-tests: -only and -omit cannot both be specified."
   withBuildSettingsFromFile:
   TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
   ];
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

- (void)testOmitListIsCollected
{
  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator6.1",
                       @"run-tests", @"-omit", @"TestProject-LibraryTests",
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  RunTestsAction *action = options.actions[0];
  assertThat((action.omitList), equalTo(@[@"TestProject-LibraryTests"]));
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

- (void)testWillComplainWhenSchemeReferencesNonExistentTestTarget
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
      // Make sure -showBuildSettings returns some data
      [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProjectWithSchemeThatReferencesNonExistentTestTarget/TestProject-Library.xcodeproj"
                                                      scheme:@"TestProject-Library"
                                                 settingsPath:TEST_DATA @"TestProjectWithSchemeThatReferencesNonExistentTestTarget-showBuildSettings.txt"],
      // We're going to call -showBuildSettings on the test target.
      [LaunchHandlers handlerForShowBuildSettingsErrorWithProject:TEST_DATA @"TestProjectWithSchemeThatReferencesNonExistentTestTarget/TestProject-Library.xcodeproj"
                                                      target:@"TestProject-Library"
                                            errorMessagePath:TEST_DATA @"TestProjectWithSchemeThatReferencesNonExistentTestTarget-TestProject-Library-showBuildSettingsError.txt"
                                                        hide:NO],
      [LaunchHandlers handlerForOtestQueryReturningTestList:@[]],
      ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[
                       @"-project", TEST_DATA @"TestProjectWithSchemeThatReferencesNonExistentTestTarget/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator",
                       @"test",
                       @"-reporter", @"plain",
                       ];

    NSDictionary *output = [TestUtil runWithFakeStreams:tool];

    assertThatInt(tool.exitStatus, equalToInt(1));
    assertThat(output[@"stdout"],
               containsString(@"Unable to read build settings for target 'TestProject-LibraryTests'."));
  }];
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

- (void)testRunTestsFailsWhenSDKIsIPHONEOS_XCTest
{
  if (!HasXCTestFramework()) {
    return;
  }

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
      // Make sure -showBuildSettings returns some data
      [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library-XCTest-iOS/TestProject-Library-XCTest-iOS.xcodeproj"
                                                      scheme:@"TestProject-Library-XCTest-iOS"
                                                settingsPath:TEST_DATA @"TestProject-Library-XCTest-iOS-showBuildSettings.txt"],
      // We're going to call -showBuildSettings on the test target.
      [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library-XCTest-iOS/TestProject-Library-XCTest-iOS.xcodeproj"
                                                      target:@"TestProject-Library-XCTest-iOSTests"
                                                settingsPath:TEST_DATA @"TestProject-Library-XCTest-iOS-TestProject-Library-XCTest-iOSTests-showBuildSettings-iphoneos.txt"
                                                        hide:NO],
      [LaunchHandlers handlerForOtestQueryReturningTestList:@[]],
    ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library-XCTest-iOS/TestProject-Library-XCTest-iOS.xcodeproj",
                       @"-scheme", @"TestProject-Library-XCTest-iOS",
                       @"-configuration", @"Debug",
                       @"run-tests",
                       @"-reporter", @"plain",
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
  NSArray *testList = @[@"TestProject_LibraryTests/testOutputMerging",
                        @"TestProject_LibraryTests/testPrintSDK",
                        @"TestProject_LibraryTests/testStream",
                        @"TestProject_LibraryTests/testWillFail",
                        @"TestProject_LibraryTests/testWillPass"];

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
     [LaunchHandlers handlerForOtestQueryReturningTestList:testList],
     [LaunchHandlers handlerForSimctlXctestRunReturningTestEvents:
       [NSData dataWithContentsOfFile:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-test-results-notests.txt"]
     ],
    ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"-destination", @"arch=i386",
                       @"run-tests",
                       @"-reporter", @"plain",
                       ];

    [TestUtil runWithFakeStreams:tool];

    NSString *action = ToolchainIsXcode7OrBetter() ? @"build" : @"test";

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(2));
    assertThat([launchedTasks[0] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"-destination", @"arch=i386",
                       @"-destination-timeout", @"10",
                       @"PLATFORM_NAME=iphonesimulator",
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-target", @"TestProject-LibraryTests",
                       @"OBJROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Intermediates",
                       @"SYMROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Intermediates/PrecompiledHeaders",
                       @"TARGETED_DEVICE_FAMILY=1",
                       action,
                       @"-showBuildSettings",
                       ]));
    assertThat([launchedTasks[0] environment][@"SHOW_ONLY_BUILD_SETTINGS_FOR_TARGET"], equalTo(@"TestProject-LibraryTests"));

    NSMutableArray *expectedArguments = [@[
      @"-NSTreatUnknownArgumentsAsOpen", @"NO",
      @"-ApplePersistenceIgnoreState", @"YES",
    ] mutableCopy];
    if (!ToolchainIsXcode7OrBetter()) {
      [expectedArguments addObjectsFromArray:@[
        @"-XCTestInvertScope", @"YES",
        @"-XCTest", @"",
        @"/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Products/Debug-iphonesimulator/TestProject-LibraryTests.xctest",
      ]];
    }
    assertThat([launchedTasks[1] arguments], containsArray(expectedArguments));
    if (ToolchainIsXcode7OrBetter()) {
      assertThat([launchedTasks[1] environment][@"SIMCTL_CHILD_XCTestConfigurationFilePath"], notNilValue());
    }

    assertThatInt(tool.exitStatus, equalToInt(1));
  }];
}

- (void)testRunTestsAction_AppleTVSimulator
{
  if (!ToolchainIsXcode7OrBetter()) {
    return;
  }

  NSString *projectPath = TEST_DATA @"TestProject-TVFramework/TestProject-TVFramework.xcodeproj";
  NSString *scheme = @"TestProject-TVFramework";
  NSString *testTarget = @"TestProject-TVFrameworkTests";
  NSArray *testList = @[
    @"TestProject_TVFrameworkTests/testPrintSDK",
    @"TestProject_TVFrameworkTests/testStream",
    @"TestProject_TVFrameworkTests/testWillPass",
    @"TestProject_TVFrameworkTests/testWillFail",
  ];

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:projectPath
                                                     scheme:scheme
                                               settingsPath:TEST_DATA @"TestProject-TVFramework-TestProject-TVFramework-showBuildSettings.txt"],
     // We're going to call -showBuildSettings on the test target.
     [LaunchHandlers handlerForShowBuildSettingsWithProject:projectPath
                                                     target:testTarget
                                               settingsPath:TEST_DATA @"TestProject-TVFramework-TestProject-TVFrameworkTests-showBuildSettings.txt"
                                                       hide:NO],
     [LaunchHandlers handlerForOtestQueryReturningTestList:testList],
     [LaunchHandlers handlerForSimctlXctestRunReturningTestEvents:
       [NSData dataWithContentsOfFile:TEST_DATA @"TestProject-TVFramework-TestProject-TVFrameworkTests-test-results.txt"]
     ],
    ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[
      @"-project", projectPath,
      @"-scheme", scheme,
      @"-configuration", @"Debug",
      @"-sdk", @"appletvsimulator",
      @"run-tests",
      @"-reporter", @"plain",
    ];

    [TestUtil runWithFakeStreams:tool];

    NSString *action = ToolchainIsXcode7OrBetter() ? @"build" : @"test";

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(2));
    assertThat([launchedTasks[0] arguments], equalTo(@[
      @"-configuration", @"Debug",
      @"-sdk", @"appletvsimulator9.1",
      @"PLATFORM_NAME=appletvsimulator",
      @"-project", projectPath,
      @"-target", testTarget,
      @"OBJROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-TVFramework-eioarvrojappukbxcyfncxozpvso/Build/Intermediates",
      @"SYMROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-TVFramework-eioarvrojappukbxcyfncxozpvso/Build/Products",
      @"SHARED_PRECOMPS_DIR=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-TVFramework-eioarvrojappukbxcyfncxozpvso/Build/Intermediates/PrecompiledHeaders",
      @"TARGETED_DEVICE_FAMILY=3",
      action,
      @"-showBuildSettings",
    ]));
    assertThat([launchedTasks[0] environment][@"SHOW_ONLY_BUILD_SETTINGS_FOR_TARGET"], equalTo(@"TestProject-TVFrameworkTests"));

    assertThat([launchedTasks[1] arguments], containsArray(@[
      @"-NSTreatUnknownArgumentsAsOpen", @"NO",
      @"-ApplePersistenceIgnoreState", @"YES",
    ]));
    assertThat([launchedTasks[1] environment][@"SIMCTL_CHILD_XCTestConfigurationFilePath"], notNilValue());
    assertThat([launchedTasks[1] environment][@"SIMCTL_CHILD_OTEST_SHIM_STDOUT_FILE"], notNilValue());

    assertThatInt(tool.exitStatus, equalToInt(XCToolActionFailed));
  }];
}

- (void)testRunTestsActionAgainstProjectWithNonExistingTargetInScheme
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    NSString *projectPath = TEST_DATA "TestProject-WithNonExistingTargetInScheme/TestProject-WithNonExistingTargetInScheme.xcodeproj";
    NSString *scheme = @"TestProject-WithNonExistingTargetInScheme";
    NSString *testTarget = @"TestProject-WithNonExistingTargetInSchemeTests";
    NSArray *testList = @[
      @"TestProject_WithNonExistingTargetInSchemeTests/testExample",
      @"TestProject_WithNonExistingTargetInSchemeTests/testPerformanceExample",
    ];
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:projectPath
                                                     scheme:scheme
                                               settingsPath:TEST_DATA @"TestProject-WithNonExistingTargetInScheme-showBuildSettings.txt"],
     // We're going to call -showBuildSettings on the test target.
     [LaunchHandlers handlerForShowBuildSettingsWithProject:projectPath
                                                     target:testTarget
                                               settingsPath:TEST_DATA @"TestProject-WithNonExistingTargetInScheme-TestProject-WithNonExistingTargetInSchemeTests-showBuildSettings.txt"
                                                       hide:NO],
     [LaunchHandlers handlerForOtestQueryReturningTestList:testList],
     [LaunchHandlers handlerForSimctlXctestRunReturningTestEvents:
       [NSData dataWithContentsOfFile:TEST_DATA @"TestProject-WithNonExistingTargetInScheme-showBuildSettings-run-tests-output.txt"]
     ],
    ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[
      @"-project", projectPath,
      @"-scheme", scheme,
      @"-configuration", @"Debug",
      @"-sdk", @"iphonesimulator",
      @"-destination", @"arch=i386",
      @"run-tests",
      @"-reporter", @"plain",
    ];

    [TestUtil runWithFakeStreams:tool];

    NSString *action = ToolchainIsXcode7OrBetter() ? @"build" : @"test";

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(2));
    assertThat([launchedTasks[0] arguments], equalTo(@[
      @"-configuration", @"Debug",
      @"-sdk", @"iphonesimulator6.1",
      @"-destination", @"arch=i386",
      @"-destination-timeout", @"10",
      @"PLATFORM_NAME=iphonesimulator",
      @"-project", projectPath,
      @"-target", testTarget,
      @"OBJROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-WithNonExistingTargetInScheme-firogdnnjipxwgadvqtehztcfdio/Build/Intermediates",
      @"SYMROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-WithNonExistingTargetInScheme-firogdnnjipxwgadvqtehztcfdio/Build/Products",
      @"SHARED_PRECOMPS_DIR=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-WithNonExistingTargetInScheme-firogdnnjipxwgadvqtehztcfdio/Build/Intermediates/PrecompiledHeaders",
      @"TARGETED_DEVICE_FAMILY=1",
      action,
      @"-showBuildSettings",
    ]));
    assertThat([launchedTasks[0] environment][@"SHOW_ONLY_BUILD_SETTINGS_FOR_TARGET"], equalTo(testTarget));
    assertThat([launchedTasks[1] arguments], containsArray(@[
      @"-NSTreatUnknownArgumentsAsOpen", @"NO",
      @"-ApplePersistenceIgnoreState", @"YES",
    ]));
    if (ToolchainIsXcode7OrBetter()) {
      assertThat([launchedTasks[1] environment][@"SIMCTL_CHILD_XCTestConfigurationFilePath"], isNot(nilValue()));
    } else {
      assertThat([launchedTasks[1] arguments], containsArray(@[
        @"-XCTestInvertScope", @"YES",
        @"-XCTest", @"",
        @"/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-WithNonExistingTargetInScheme-firogdnnjipxwgadvqtehztcfdio/Build/Products/Release-iphonesimulator/TestProject-WithNonExistingTargetInSchemeTests.xctest",
      ]));
    }
    assertThatInt(tool.exitStatus, equalToInt(XCToolAllActionsSucceeded));
  }];
}

- (void)testRunTestsActionWithListTestsOnlyOption
{
  NSString *projectPath = TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj";
  NSString *scheme = @"TestProject-Library";
  NSString *testTarget = @"TestProject-LibraryTests";
  NSArray *testList = @[@"TestProject_LibraryTests/testOutputMerging",
                        @"TestProject_LibraryTests/testPrintSDK",
                        @"TestProject_LibraryTests/testStream",
                        @"TestProject_LibraryTests/testWillFail",
                        @"TestProject_LibraryTests/testWillPass"];

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
      // Make sure -showBuildSettings returns some data
      [LaunchHandlers handlerForShowBuildSettingsWithProject:projectPath
                                                      scheme:scheme
                                                settingsPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"],
      // We're going to call -showBuildSettings on the test target.
      [LaunchHandlers handlerForShowBuildSettingsWithProject:projectPath
                                                      target:testTarget
                                                settingsPath:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-showBuildSettings.txt"
                                                        hide:NO],
      [LaunchHandlers handlerForOtestQueryReturningTestList:testList],
    ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[
      @"-project", projectPath,
      @"-scheme", scheme,
      @"-configuration", @"Debug",
      @"-sdk", @"iphonesimulator6.0",
      @"-destination", @"arch=i386",
      @"run-tests",
      @"listTestsOnly",
      @"-reporter", @"json-stream"
    ];

    NSDictionary *result = [TestUtil runWithFakeStreams:tool];
    NSString *listTestsOnlyOutput = [NSString stringWithContentsOfFile:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-run-test-results-listtestonly.txt"
                                                              encoding:NSUTF8StringEncoding
                                                                 error:nil];
    NSString *escapedTestDataPath = [TEST_DATA stringByReplacingOccurrencesOfString:@"/" withString:@"\\/"];
    NSString *stdoutString = [result[@"stdout"] stringByReplacingOccurrencesOfString:escapedTestDataPath withString:@"xctool-tests\\/TestData\\/"];
    assertThatBool(areEqualJsonOutputsIgnoringKeys(stdoutString, listTestsOnlyOutput, @[@"timestamp", @"duration", @"deviceName", @"sdkName"]), isTrue());
  }];
}

- (void)testCanRunTestsWithCustomMethodNames
{
  XCTool *tool = [[XCTool alloc] init];

  tool.arguments = @[@"-sdk", @"macosx",
                     @"run-tests",
                     @"-logicTest", TEST_DATA @"tests-osx-test-bundle/TestProject-Library-XCTest-CustomTests.xctest"
                     ];

  NSDictionary *output = [TestUtil runWithFakeStreams:tool];
  assertThatInt(tool.exitStatus, equalToInt(0));
  assertThat(output[@"stdout"], containsString(@"-[TestProject_Library_XCTest_CustomTests customTest]"));
  assertThat(output[@"stdout"], containsString(@"-[TestProject_Library_XCTest_CustomTests customTestWithInteger:]"));
  assertThat(output[@"stdout"], containsString(@"SUCCEEDED"));
}

- (void)testCanRunTestsAgainstDifferentTestSDK
{
  NSString *projectPath = TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj";
  NSString *scheme = @"TestProject-Library";
  NSString *testTarget = @"TestProject-LibraryTests";
  NSArray *testList = @[
    @"TestProject_LibraryTests/testBacktraceOutputIsCaptured",
    @"TestProject_LibraryTests/testOutputMerging",
    @"TestProject_LibraryTests/testPrintSDK",
    @"TestProject_LibraryTests/testStream",
    @"TestProject_LibraryTests/testWillFail",
    @"TestProject_LibraryTests/testWillPass",
  ];

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:projectPath
                                                     scheme:scheme
                                               settingsPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"],
     // We're going to call -showBuildSettings on the test target.
     [LaunchHandlers handlerForShowBuildSettingsWithProject:projectPath
                                                     target:testTarget
                                               settingsPath:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-showBuildSettings.txt"
                                                       hide:NO],
     [LaunchHandlers handlerForOtestQueryReturningTestList:testList],
     [LaunchHandlers handlerForSimctlXctestRunReturningTestEvents:
       [NSData dataWithContentsOfFile:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-test-results.txt"]
     ],
    ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[
      @"-project", projectPath,
      @"-scheme", scheme,
      @"-configuration", @"Debug",
      @"-sdk", @"iphonesimulator6.0",
      @"-destination", @"arch=i386",
      @"run-tests", @"-test-sdk", @"iphonesimulator5.0",
      @"-reporter", @"plain",
    ];

    [TestUtil runWithFakeStreams:tool];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];

    NSString *action = ToolchainIsXcode7OrBetter() ? @"build" : @"test";

    assertThatInteger([launchedTasks count], equalToInteger(2));
    assertThat([launchedTasks[0] arguments], equalTo(@[
      @"-configuration", @"Debug",
      @"-sdk", @"iphonesimulator5.0",
      @"-destination", @"arch=i386",
      @"-destination-timeout", @"10",
      @"PLATFORM_NAME=iphonesimulator",
      @"-project", projectPath,
      @"-target", testTarget,
      @"OBJROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Intermediates",
      @"SYMROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Products",
      @"SHARED_PRECOMPS_DIR=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Intermediates/PrecompiledHeaders",
      @"TARGETED_DEVICE_FAMILY=1",
      action,
      @"-showBuildSettings",
    ]));
    assertThat([launchedTasks[0] environment][@"SHOW_ONLY_BUILD_SETTINGS_FOR_TARGET"], equalTo(@"TestProject-LibraryTests"));
    NSMutableArray *expectedArguments = [@[
      @"-NSTreatUnknownArgumentsAsOpen", @"NO",
      @"-ApplePersistenceIgnoreState", @"YES",
    ] mutableCopy];
    if (!ToolchainIsXcode7OrBetter()) {
      [expectedArguments addObjectsFromArray:@[
        @"-XCTestInvertScope", @"YES",
        @"-XCTest", @"",
        @"/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Products/Debug-iphonesimulator/TestProject-LibraryTests.xctest"
      ]];
    }
    assertThat([launchedTasks[1] arguments], containsArray(expectedArguments));
    if (ToolchainIsXcode7OrBetter()) {
      assertThat([launchedTasks[1] environment][@"SIMCTL_CHILD_XCTestConfigurationFilePath"], notNilValue());
    }
    assertThatInt(tool.exitStatus, equalToInt(XCToolActionFailed));
  }];
}

- (void)testCanSelectSpecificTestClassOrTestMethodsWithOnlyAndOmit
{
  NSString *projectPath = TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj";
  NSString *scheme = @"TestProject-Library";
  NSString *testTarget = @"TestProject-LibraryTests";
  NSArray *testList = @[
    @"OtherTests/testSomething",
    @"SomeTests/testBacktraceOutputIsCaptured",
    @"SomeTests/testOutputMerging",
    @"SomeTests/testPrintSDK",
    @"SomeTests/testStream",
    @"SomeTests/testWillFail",
    @"SomeTests/testWillPass",
  ];

  void (^runWithArguments)(NSString *, NSArray *, BOOL) = ^(NSString *argument, NSArray *values, BOOL skipTarget) {
    [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
        // Make sure -showBuildSettings returns some data
        [LaunchHandlers handlerForShowBuildSettingsWithProject:projectPath
                                                        scheme:scheme
                                                  settingsPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"],
        // We're going to call -showBuildSettings on the test target.
        [LaunchHandlers handlerForShowBuildSettingsWithProject:projectPath
                                                        target:testTarget
                                                  settingsPath:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-showBuildSettings.txt"
                                                          hide:NO],
        [LaunchHandlers handlerForOtestQueryReturningTestList:testList],
        [LaunchHandlers handlerForSimctlXctestRunReturningTestEvents:
          [NSData dataWithContentsOfFile:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-test-results-notests.txt"]
        ],
      ]];

      XCTool *tool = [[XCTool alloc] init];
      NSMutableArray *args = [@[
        @"-project", projectPath,
        @"-scheme", scheme,
        @"-configuration", @"Debug",
        @"-sdk", @"iphonesimulator6.0",
        @"-destination", @"arch=i386",
        @"run-tests"
      ] mutableCopy];
      for (NSString *value in values) {
        [args addObject:argument];
        [args addObject:value];
      }
      [args addObjectsFromArray:@[@"-reporter", @"plain"]];
      tool.arguments = args;

      [TestUtil runWithFakeStreams:tool];

      NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
      if (skipTarget) {
        assertThatInteger([launchedTasks count], equalToInteger(0));
      } else {
        assertThatInteger([launchedTasks count], equalToInteger(2));
        NSMutableArray *expectedArguments = [@[
          @"-NSTreatUnknownArgumentsAsOpen", @"NO",
          @"-ApplePersistenceIgnoreState", @"YES",
        ] mutableCopy];
        if (!ToolchainIsXcode7OrBetter()) {
          [expectedArguments addObjectsFromArray:@[
            @"-XCTestInvertScope", @"YES",
            @"-XCTestScopeFile",
          ]];
        }
        assertThat([launchedTasks[1] arguments], containsArray(expectedArguments));
        if (!ToolchainIsXcode7OrBetter()) {
          assertThat([[launchedTasks[1] arguments] lastObject], is(@"/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Products/Debug-iphonesimulator/TestProject-LibraryTests.xctest"));
        }
        if (ToolchainIsXcode7OrBetter()) {
          assertThat([launchedTasks[1] environment][@"SIMCTL_CHILD_XCTestConfigurationFilePath"], notNilValue());
        }
      }
    }];
  };

  runWithArguments(@"-only", @[@"TestProject-LibraryTests:SomeTests/testOutputMerging"], NO);
  runWithArguments(@"-only", @[@"TestProject-LibraryTests:SomeTests/testWillPass"], NO);
  runWithArguments(@"-only", @[@"TestProject-LibraryTests:SomeTests/testWillPass,OtherTests/testSomething"], NO);
  runWithArguments(@"-only", @[@"TestProject-LibraryTests:SomeTests/testWillPass",
                               @"TestProject-LibraryTests:SomeTests/testWillFail"], NO);
  runWithArguments(@"-only", @[@"TestProject-LibraryTests",
                               @"TestProject-LibraryTests:SomeTests/testWillFail"], NO);
  runWithArguments(@"-only", @[@"TestProject-LibraryTests:SomeTests/testWillPass",
                               @"TestProject-LibraryTests"], NO);
  runWithArguments(@"-omit", @[@"TestProject-LibraryTests:SomeTests/testOutputMerging"], NO);
  runWithArguments(@"-omit", @[@"TestProject-LibraryTests:SomeTests/testWillPass"], NO);
  runWithArguments(@"-omit", @[@"TestProject-LibraryTests:SomeTests/testWillPass,OtherTests/testSomething"], NO);
  runWithArguments(@"-omit", @[@"TestProject-LibraryTests:SomeTests/testWillPass",
                               @"TestProject-LibraryTests:SomeTests/testWillFail,SomeTests/testOutputMerging"], NO);
  runWithArguments(@"-omit", @[@"TestProject-LibraryTests",
                               @"TestProject-LibraryTests:SomeTests/testWillFail,SomeTests/testOutputMerging"], YES);
  runWithArguments(@"-omit", @[@"TestProject-LibraryTests:SomeTests/testWillPass",
                               @"TestProject-LibraryTests"], YES);
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
     [LaunchHandlers handlerForOtestQueryReturningTestList:@[@"FakeTest/TestA", @"FakeTest/TestB"]],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-project", TEST_DATA @"TestsWithArgAndEnvSettingsInRunAction/TestsWithArgAndEnvSettings.xcodeproj",
                       @"-scheme", @"TestsWithArgAndEnvSettings",
                       @"run-tests",
                       @"-reporter", @"plain",
                       ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTests)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = self;
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       assertThat(runner, notNilValue());
       assertThat([runner valueForKey:@"arguments"],
                  equalTo(@[@"-RunArg", @"RunArgValue"]));
       assertThat([runner valueForKey:@"environment"],
                  equalTo(@{@"RunEnvKey" : @"RunEnvValue"}));
     }];

  }];
}

/**
 Optionally, Xcode can also run your tests with specific args or environment
 vars that you've configured for your Test action in the scheme editor.
 Also we are verifying that process environment isn't passed to iOS tests.
 */
- (void)testSchemeArgsAndEnvForTestActionArePassedToTestRunner_iOS
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    NSString *projectPath = TEST_DATA @"TestProject-Library-XCTest-iOS/TestProject-Library-XCTest-iOS.xcodeproj";
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
      // Make sure -showBuildSettings returns some data
      [LaunchHandlers handlerForShowBuildSettingsWithProject:projectPath
                                                      scheme:@"TestProject-Library-XCTest-iOS"
                                                settingsPath:TEST_DATA @"TestProject-Library-XCTest-iOS-showBuildSettings.txt"],
      // We're going to call -showBuildSettings on the test target.
      [LaunchHandlers handlerForShowBuildSettingsWithProject:projectPath
                                                      target:@"TestProject-Library-XCTest-iOSTests"
                                                settingsPath:TEST_DATA @"TestProject-Library-XCTest-iOS-TestProject-Library-XCTest-iOSTests-showBuildSettings-iphonesimulator.txt"
                                                        hide:NO],
      [LaunchHandlers handlerForOtestQueryReturningTestList:@[@"FakeTest/TestA", @"FakeTest/TestB"]],
    ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-project", projectPath,
                       @"-scheme", @"TestProject-Library-XCTest-iOS",
                       @"run-tests",
                       @"-reporter", @"plain",
                       ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTests)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = self;
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       NSMutableDictionary *expectedEnv = [@{
         @"TestEnvKey" : @"TestEnvValue",
       } mutableCopy];

       assertThat(runner, notNilValue());
       assertThat([runner valueForKey:@"arguments"],
                  equalTo(@[@"-TestArg", @"TestArgValue"]));
       assertThat([runner valueForKey:@"environment"],
                  equalTo(expectedEnv));

       NSString *pathToOtestShimDylib = @"/pretend/this/is/otest-shim-osx.dylib";
       expectedEnv[@"DYLD_INSERT_LIBRARIES"] = pathToOtestShimDylib;

       assertThat([runner otestEnvironmentWithOverrides:@{@"DYLD_INSERT_LIBRARIES" : pathToOtestShimDylib}],
                  equalTo(expectedEnv));
     }];
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
                                               settingsPath:TEST_DATA @"TestsWithArgAndEnvSettingsInRunAction-TestsWithArgAndEnvSettings-showBuildSettings.txt"],
     // We're going to call -showBuildSettings on the test target.
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestsWithArgAndEnvSettingsInTestAction/TestsWithArgAndEnvSettings.xcodeproj"
                                                     target:@"TestsWithArgAndEnvSettingsTests"
                                               settingsPath:TEST_DATA @"TestsWithArgAndEnvSettingsInRunAction-TestsWithArgAndEnvSettings-TestsWithArgAndEnvSettingsTests-showBuildSettings.txt"
                                                       hide:NO],
     [LaunchHandlers handlerForOtestQueryReturningTestList:@[@"FakeTest/TestA", @"FakeTest/TestB"]],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-project", TEST_DATA @"TestsWithArgAndEnvSettingsInTestAction/TestsWithArgAndEnvSettings.xcodeproj",
                       @"-scheme", @"TestsWithArgAndEnvSettings",
                       @"run-tests",
                       @"-reporter", @"plain",
                       ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTests)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = self;
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       assertThat(runner, notNilValue());
       assertThat([runner valueForKey:@"arguments"],
                  equalTo(@[@"-TestArg", @"TestArgValue"]));
       assertThat([runner valueForKey:@"environment"],
                  equalTo(@{@"TestEnvKey" : @"TestEnvValue"}));
     }];

  }];
}

/**
 Xcode will let you use macros like $(SOMEVAR) in the arguments or environment
 variables specified in your scheme.
 Also we are verifying that process environment is passed to OS X tests.
 */
- (void)testSchemeArgsAndEnvCanUseMacroExpansion
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestsWithArgAndEnvSettingsWithMacroExpansion/TestsWithArgAndEnvSettings.xcodeproj"
                                                     scheme:@"TestsWithArgAndEnvSettings"
                                               settingsPath:TEST_DATA @"TestsWithArgAndEnvSettingsInRunAction-TestsWithArgAndEnvSettings-showBuildSettings.txt"],
     // We're going to call -showBuildSettings on the test target.
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestsWithArgAndEnvSettingsWithMacroExpansion/TestsWithArgAndEnvSettings.xcodeproj"
                                                     target:@"TestsWithArgAndEnvSettingsTests"
                                               settingsPath:TEST_DATA @"TestsWithArgAndEnvSettingsInRunAction-TestsWithArgAndEnvSettings-TestsWithArgAndEnvSettingsTests-showBuildSettings.txt"
                                                       hide:NO],
     [LaunchHandlers handlerForOtestQueryReturningTestList:@[@"FakeTest/TestA", @"FakeTest/TestB"]],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-project", TEST_DATA @"TestsWithArgAndEnvSettingsWithMacroExpansion/TestsWithArgAndEnvSettings.xcodeproj",
                       @"-scheme", @"TestsWithArgAndEnvSettings",
                       @"run-tests",
                       @"-reporter", @"plain",
                       ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTests)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = self;
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       NSMutableDictionary *expectedEnv = [@{
         @"DYLD_INSERT_LIBRARIES": @"ThisShouldNotGetOverwrittenByOtestShim",
         @"RunEnvKey": @"RunEnvValue",
         @"ARCHS": @"x86_64",
       } mutableCopy];

       assertThat(runner, notNilValue());
       assertThat([runner valueForKey:@"arguments"],
                  equalTo(@[]));
       assertThat([runner valueForKey:@"environment"],
                  equalTo(expectedEnv));

       NSString *pathToOtestShimDylib = @"/pretend/this/is/otest-shim-osx.dylib";
       expectedEnv[@"DYLD_INSERT_LIBRARIES"] = [@[expectedEnv[@"DYLD_INSERT_LIBRARIES"], pathToOtestShimDylib] componentsJoinedByString:@":"];

       [expectedEnv addEntriesFromDictionary:[[NSProcessInfo processInfo] environment]];
       assertThat([runner otestEnvironmentWithOverrides:@{@"DYLD_INSERT_LIBRARIES" : pathToOtestShimDylib}],
                  equalTo(expectedEnv));
     }];

  }];
}

- (void)testConfigurationIsTakenFromScheme
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj"
                                                     scheme:@"TestProject-Library"
                                               settingsPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"],
     // We're going to call -showBuildSettings on the test target.
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj"
                                                     target:@"TestProject-LibraryTests"
                                               settingsPath:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-showBuildSettings.txt"
                                                       hide:NO],
     [LaunchHandlers handlerForOtestQueryReturningTestList:@[@"FakeTest/TestA", @"FakeTest/TestB"]],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator",
                       @"-arch", @"i386",
                       @"-destination", @"arch=i386",
                       @"run-tests",
                       @"-reporter", @"plain",
                       ];

    [TestUtil runWithFakeStreams:tool];

    NSString *action = ToolchainIsXcode7OrBetter() ? @"build" : @"test";

    assertThat([[[FakeTaskManager sharedManager] launchedTasks][0] arguments],
               equalTo(@[
                       @"-configuration",
                       @"TestConfig",
                       @"-sdk",
                       @"iphonesimulator6.1",
                       @"-arch",
                       @"i386",
                       @"-destination", @"arch=i386",
                       @"-destination-timeout", @"10",
                       @"PLATFORM_NAME=iphonesimulator",
                       @"-project",
                       TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj",
                       @"-target",
                       @"TestProject-LibraryTests",
                       @"OBJROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Intermediates",
                       @"SYMROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Intermediates/PrecompiledHeaders",
                       @"TARGETED_DEVICE_FAMILY=1",
                       action,
                       @"-showBuildSettings",
                       ]));
    assertThat([[[FakeTaskManager sharedManager] launchedTasks][0] environment][@"SHOW_ONLY_BUILD_SETTINGS_FOR_TARGET"], equalTo(@"TestProject-LibraryTests"));
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
  // If there are no tests, we should get an empty bucket.
  assertThat(BucketizeTestCasesByTestCase(@[], 3), equalTo(@[@[]]));
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
  // If there are no tests, we should get an empty bucket.
  assertThat(BucketizeTestCasesByTestClass(@[], 3), equalTo(@[@[]]));
}

- (void)testTestRunningWithNoTestsPresentInOptions
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      Options *options = [Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator6.1",
                       @"run-tests",
          ]];
      id testRunning = options.actions[0];
      assertThat(testRunning, conformsTo(@protocol(TestRunning)));
      assertThatBool([testRunning testsPresentInOptions], isFalse());
  }];
}

- (void)testTestRunningWithLogicTestPresentInOptions
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      Options *options = [[Options optionsFrom:@[
                              @"-sdk", @"iphonesimulator6.1",
                              @"run-tests",
                              @"-logicTest", TEST_DATA @"tests-ios-test-bundle/TestProject-LibraryTests.octest",
            ]] assertOptionsValidate];
      id testRunning = options.actions[0];
      assertThat(testRunning, conformsTo(@protocol(TestRunning)));
      assertThatBool([testRunning testsPresentInOptions], isTrue());
  }];
}

- (void)testTestRunningWithAppTestPresentInOptions
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      Options *options = [[Options optionsFrom:@[
                              @"-sdk", @"iphonesimulator6.1",
                              @"run-tests",
                              @"-appTest",
                              TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSXTests.xctest:"
                              TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX",
            ]] assertOptionsValidate];
      id testRunning = options.actions[0];
      assertThat(testRunning, conformsTo(@protocol(TestRunning)));
      assertThatBool([testRunning testsPresentInOptions], isTrue());
  }];
}

- (void)testActionOptionLogicTests
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      Options *options = [[Options optionsFrom:@[
                              @"-sdk", @"iphonesimulator6.1",
                              @"run-tests",
                              @"-logicTest", TEST_DATA @"tests-ios-test-bundle/TestProject-LibraryTests.octest",
            ]] assertOptionsValidate];
      RunTestsAction *action = options.actions[0];
      assertThat(action.logicTests, equalTo(@[TEST_DATA @"tests-ios-test-bundle/TestProject-LibraryTests.octest"]));
  }];
}

- (void)testActionOptionMultipleLogicTests
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      Options *options = [[Options optionsFrom:@[
                              @"-sdk", @"iphonesimulator6.1",
                              @"run-tests",
                              @"-logicTest", TEST_DATA @"tests-ios-test-bundle/TestProject-LibraryTests.octest",
                              @"-logicTest", TEST_DATA @"tests-ios-test-bundle/SenTestingKit_Assertion.octest",
            ]] assertOptionsValidate];
      RunTestsAction *action = options.actions[0];
      assertThat(
        action.logicTests,
        equalTo(
          @[
            TEST_DATA @"tests-ios-test-bundle/TestProject-LibraryTests.octest",
            TEST_DATA @"tests-ios-test-bundle/SenTestingKit_Assertion.octest"]));
  }];
}

- (void)testActionOptionAppTest
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      Options *options = [[Options optionsFrom:@[
                              @"-sdk", @"macosx10.7",
                              @"run-tests",
                              @"-appTest",
                              TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSXTests.xctest:"
                              TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX",

            ]] assertOptionsValidate];
      RunTestsAction *action = options.actions[0];
      assertThat(
        action.appTests,
        equalTo(
          @{
            TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSXTests.xctest" :
              TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX",
           }));
  }];
}

- (void)testActionOptionMultipleAppTests
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      Options *options = [[Options optionsFrom:@[
                              @"-sdk", @"macosx10.7",
                              @"run-tests",
                              @"-appTest",
                              TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSXTests.xctest:"
                              TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX",
                              @"-appTest",
                              TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator/KiwiTests-OCUnit-AppTests.octest:"
                              TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator/KiwiTests-TestHost.app/KiwiTests-TestHost",
            ]] assertOptionsValidate];
      RunTestsAction *action = options.actions[0];
      assertThat(
        action.appTests,
        equalTo(
          @{
            TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSXTests.xctest" :
              TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX",
            TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator/KiwiTests-OCUnit-AppTests.octest" :
              TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator/KiwiTests-TestHost.app/KiwiTests-TestHost",
           }));
  }];
}

- (void)testActionOptionMixedLogicAndAppTests
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      Options *options = [[Options optionsFrom:@[
                              @"-sdk", @"macosx10.7",
                              @"run-tests",
                              @"-logicTest", TEST_DATA @"tests-ios-test-bundle/TestProject-LibraryTests.octest",
                              @"-appTest",
                              TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSXTests.xctest:"
                              TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX",
                              @"-logicTest", TEST_DATA @"tests-ios-test-bundle/SenTestingKit_Assertion.octest",
                              @"-appTest",
                              TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator/KiwiTests-OCUnit-AppTests.octest:"
                              TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator/KiwiTests-TestHost.app/KiwiTests-TestHost",
            ]] assertOptionsValidate];
      RunTestsAction *action = options.actions[0];
      assertThat(
        action.logicTests,
        equalTo(
          @[
            TEST_DATA @"tests-ios-test-bundle/TestProject-LibraryTests.octest",
            TEST_DATA @"tests-ios-test-bundle/SenTestingKit_Assertion.octest"]));
      assertThat(
        action.appTests,
        equalTo(
          @{
            TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSXTests.xctest" :
              TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX",
            TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator/KiwiTests-OCUnit-AppTests.octest" :
              TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator/KiwiTests-TestHost.app/KiwiTests-TestHost",
           }));
  }];
}

- (void)testWillComplainWhenPassingLogicTestThatDoesntExist
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      [[Options optionsFrom:@[
                              @"-sdk", @"iphonesimulator6.1",
                              @"run-tests",
                              @"-logicTest", TEST_DATA @"path/to/this-does-not-exist.xctest",
                              ]]
       assertOptionsFailToValidateWithError:
           @"run-tests: Logic test at path '" TEST_DATA @"path/to/this-does-not-exist.xctest' does not exist or is not a directory"];

  }];
}

- (void)testWillComplainWhenPassingAppTestThatDoesntExist
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      [[Options optionsFrom:@[
                              @"-sdk", @"iphonesimulator6.1",
                              @"run-tests",
                              @"-appTest", TEST_DATA @"path/to/this-does-not-exist.xctest:path/to/HostApp.app/HostApp",
                              ]]
       assertOptionsFailToValidateWithError:
           @"run-tests: Application test at path '" TEST_DATA @"path/to/this-does-not-exist.xctest' does not exist or is not a directory"];

  }];
}

- (void)testWillComplainWhenPassingHostAppBinaryThatDoesntExist
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      [[Options optionsFrom:@[
                              @"-sdk", @"iphonesimulator6.1",
                              @"run-tests",
                              @"-appTest", TEST_DATA @"tests-ios-test-bundle/TestProject-Library-XCTest-iOSTests.xctest:"
                                           TEST_DATA @"path/to/NonExistentHostApp.app/HostApp",
                              ]]
       assertOptionsFailToValidateWithError:
           @"run-tests: Application test host binary at path '" TEST_DATA "path/to/NonExistentHostApp.app/HostApp' does not exist or is not a file"];

  }];
}

- (void)testWillComplainWhenPassingSameLogicTestForMultipleTestHostApps
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      [[Options optionsFrom:@[
                              @"-sdk", @"iphonesimulator6.1",
                              @"run-tests",
                              @"-appTest", TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSXTests.xctest:"
                                TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX",
                              @"-appTest", TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSXTests.xctest:"
                                TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX",
                              ]]
       assertOptionsFailToValidateWithError:
           @"run-tests: The same test bundle '"TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSXTests.xctest' cannot test "
           @"more than one test host app (got '"TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX' and '" TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX')"];
  }];
}

- (void)testPassingLogicTestViaCommandLine
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     [LaunchHandlers handlerForOtestQueryReturningTestList:@[@"FakeTest/TestA", @"FakeTest/TestB"]],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-sdk", @"iphonesimulator6.1",
                       @"run-tests",
                        @"-logicTest", TEST_DATA @"tests-ios-test-bundle/TestProject-LibraryTests.octest",
                      ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTests)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = self;
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       assertThat(runner, notNilValue());
       assertThat([runner.simulatorInfo productBundlePath], equalTo(TEST_DATA @"tests-ios-test-bundle/TestProject-LibraryTests.octest"));
     }];
  }];
}

- (void)testi386CpuTypeReadFromLogicTestBundle
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     [LaunchHandlers handlerForOtestQueryReturningTestList:@[@"FakeTest/TestA", @"FakeTest/TestB"]],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-sdk", @"iphonesimulator",
                       @"run-tests",
                       @"-logicTest", TEST_DATA @"tests-ios-test-bundle/TestProject-LibraryTests.octest",
                      ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTests)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = self;
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       assertThat(runner, notNilValue());
       assertThatInteger([runner.simulatorInfo simulatedCpuType], equalToInteger(CPU_TYPE_I386));
     }];
  }];
}

- (void)testX86_64CpuTypeReadFromLogicTestBundle
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     [LaunchHandlers handlerForOtestQueryReturningTestList:@[@"FakeTest/TestA", @"FakeTest/TestB"]],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-sdk", @"iphonesimulator6.1",
                       @"run-tests",
                       @"-logicTest", TEST_DATA @"tests-ios-test-bundle/TestProject-Library-64bitTests.xctest",
                      ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTests)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = self;
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       assertThat(runner, notNilValue());
       assertThatInteger([runner.simulatorInfo simulatedCpuType], equalToInteger(CPU_TYPE_X86_64));
     }];
  }];
}

- (void)testAnyCpuTypeReadFromLogicTestBundle
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     [LaunchHandlers handlerForOtestQueryReturningTestList:@[@"FakeTest/TestA", @"FakeTest/TestB"]],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-sdk", @"iphonesimulator6.1",
                       @"run-tests",
                       @"-logicTest", TEST_DATA @"tests-ios-test-bundle/TestProject-Library-32And64bitTests.xctest"
                      ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTests)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = self;
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       assertThat(runner, notNilValue());
       assertThatInteger([runner.simulatorInfo simulatedCpuType], equalToInteger(CPU_TYPE_ANY));
     }];
  }];
}

- (void)testX86_64CpuTypeReadFromAppTestBundle
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
      [LaunchHandlers handlerForOtestQueryWithTestHost:TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX"
                                     returningTestList:@[@"FakeTest/TestA", @"FakeTest/TestB"]],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-sdk", @"macosx10.8",
                       @"run-tests",
                       @"-appTest",
                       TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSXTests.xctest:" TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX",
                       ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTests)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = self;
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       assertThat(runner, notNilValue());
       assertThatInteger([runner.simulatorInfo simulatedCpuType], equalToInteger(CPU_TYPE_X86_64));
     }];
  }];
}

- (void)testi386CpuTypeReadFromAppTestBundle
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
      [LaunchHandlers handlerForOtestQueryWithTestHost:TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator/KiwiTests-TestHost.app/KiwiTests-TestHost"
                                     returningTestList:@[@"FakeTest/TestA", @"FakeTest/TestB"]],
    ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-sdk", @"iphonesimulator6.1",
                       @"run-tests",
                       @"-appTest",
                       TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator/KiwiTests-OCUnit-AppTests.octest:"
                         TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator/KiwiTests-TestHost.app/KiwiTests-TestHost",
                      ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTests)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = self;
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       assertThat(runner, notNilValue());
       assertThatInteger([runner.simulatorInfo simulatedCpuType], equalToInteger(CPU_TYPE_I386));
     }];
  }];
}

- (void)testTestHostArchitectureIsUsedWhenTestBundleArchitectureIsDifferent
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
      [LaunchHandlers handlerForOtestQueryWithTestHost:TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX"
                                     returningTestList:@[@"FakeTest/TestA", @"FakeTest/TestB"]],
    ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[
      @"-sdk", @"iphonesimulator",
      @"run-tests",
      @"-appTest",
      TEST_DATA @"tests-ios-test-bundle/TestProject-LibraryTests.octest:" TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX",
    ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTests)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = self;
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       assertThat(runner, notNilValue());
       assertThatInteger([runner.simulatorInfo simulatedCpuType], equalToInteger(CPU_TYPE_X86_64));
     }];
  }];
}

- (void)testTestHostArchitectureIsUsedWhenTestBundleArchitectureIsSame
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
      [LaunchHandlers handlerForOtestQueryWithTestHost:TEST_DATA @"FakeApp.app/FakeApp"
                                     returningTestList:@[@"FakeTest/TestA", @"FakeTest/TestB"]],
    ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[
      @"-sdk", @"iphonesimulator",
      @"run-tests",
      @"-appTest",
      TEST_DATA @"tests-ios-test-bundle/TestProject-LibraryTests.octest:" TEST_DATA @"FakeApp.app/FakeApp",
    ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTests)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = self;
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       assertThat(runner, notNilValue());
       assertThatInteger([runner.simulatorInfo simulatedCpuType], equalToInteger(CPU_TYPE_I386));
     }];
  }];
}

- (void)testTestBundleArchitectureIsUsedWhenTestHostIsUniversal
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
      [LaunchHandlers handlerForOtestQueryWithTestHost:TEST_DATA @"TestProject64bit/TestProject64bit.app/TestProject64bit"
                                     returningTestList:@[@"FakeTest/TestA", @"FakeTest/TestB"]],
    ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[
      @"-sdk", @"iphonesimulator",
      @"run-tests",
      @"-appTest",
      TEST_DATA @"tests-ios-test-bundle/TestProject-LibraryTests.octest:" TEST_DATA @"TestProject64bit/TestProject64bit.app/TestProject64bit",
    ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTests)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = self;
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       assertThat(runner, notNilValue());
       assertThatInteger([runner.simulatorInfo simulatedCpuType], equalToInteger(CPU_TYPE_I386));
     }];
  }];
}

- (void)testPassingAppTestViaCommandLine
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
        [LaunchHandlers handlerForOtestQueryWithTestHost:TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX"
                                        returningTestList:@[@"FakeTest/TestA", @"FakeTest/TestB"]],
        ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-sdk", @"macosx10.8",
                       @"run-tests",
                       @"-appTest",
                       TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSXTests.xctest:" TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX",
                       ];

    __block OCUnitTestRunner *runner = nil;

    [Swizzler whileSwizzlingSelector:@selector(runTests)
                 forInstancesOfClass:[OCUnitTestRunner class]
                           withBlock:
     ^(id self, SEL sel){
       // Don't actually run anything and just save a reference to the runner.
       runner = self;
       // Pretend tests succeeded.
       return YES;
     }
                            runBlock:
     ^{
       [TestUtil runWithFakeStreams:tool];

       assertThat(runner, notNilValue());
       assertThat([runner.simulatorInfo productBundlePath], equalTo(TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSXTests.xctest"));
     }];
  }];
}

@end
