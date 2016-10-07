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
#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "LaunchHandlers.h"
#import "Options.h"
#import "TaskUtil.h"
#import "TestUtil.h"
#import "XCTool.h"
#import "XCToolUtil.h"
#import "xcodeSubjectInfo.h"

void _CFAutoreleasePoolPrintPools();

@interface BuildActionTests : XCTestCase
@end

@implementation BuildActionTests

- (void)testBuildActionPassesSDKParamToXcodebuild
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"
                                                           scheme:@"TestProject-Library"
                                                     settingsPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"],
    ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator6.0",
                       @"build",
                       @"-reporter", @"plain",
                       ];

    [TestUtil runWithFakeStreams:tool];

    assertThat([[[FakeTaskManager sharedManager] launchedTasks][0] arguments],
               equalTo(@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"PLATFORM_NAME=iphonesimulator",
                       @"build",
                       ]));
  }];
}

- (void)testBuildActionTriggersBuildForProjectAndScheme
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"
                                                           scheme:@"TestProject-Library"
                                                     settingsPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"build",
                       @"-reporter", @"plain",
                       ];

    [TestUtil runWithFakeStreams:tool];

    assertThat([[[FakeTaskManager sharedManager] launchedTasks][0] arguments],
               equalTo(@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Debug",
                       @"build",
                       ]));
  }];
}

- (void)testBuildActionTriggersBuildForWorkspaceAndScheme
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithWorkspace:TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace"
                                                       scheme:@"TestProject-Library"
                                                 settingsPath:TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                       @"-scheme", @"TestProject-Library",
                       @"build",
                       @"-reporter", @"plain",
                       ];

    [TestUtil runWithFakeStreams:tool];

    assertThat([[[FakeTaskManager sharedManager] launchedTasks][0] arguments],
               equalTo(@[
                       @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Debug",
                       @"build",
                       ]));
  }];
}

- (void)testBuildActionPassesConfigurationParamToXcodebuild
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"
                                                     scheme:@"TestProject-Library"
                                               settingsPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"SOME_CONFIGURATION",
                       @"build",
                       @"-reporter", @"plain",
                       ];

    [TestUtil runWithFakeStreams:tool];

    assertThat([[[FakeTaskManager sharedManager] launchedTasks][0] arguments],
               equalTo(@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"SOME_CONFIGURATION",
                       @"build",
                       ]));
  }];
}

- (void)testIfBuildActionFailsThenExitStatusShouldBeOne
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  void (^testWithExitStatus)(int) = ^(int exitStatus) {
    [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
       // Make sure -showBuildSettings returns some data
       [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"
                                                       scheme:@"TestProject-Library"
                                                 settingsPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"],
       [^(FakeTask *task){
        if ([[task launchPath] hasSuffix:@"xcodebuild"] &&
            [[task arguments] containsObject:@"build"]) {
          // Pretend the task has a specific exit code.
          [task pretendExitStatusOf:exitStatus];
        }
      } copy],
       ]];

      XCTool *tool = [[XCTool alloc] init];

      tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                         @"-scheme", @"TestProject-Library",
                         @"build",
                         @"-reporter", @"plain",
                         ];

      [TestUtil runWithFakeStreams:tool];

      assertThatInt(tool.exitStatus, equalToInt(exitStatus));
    }];
  };

  // Pretend xcodebuild succeeds, and so we should succeed.
  testWithExitStatus(0);

  // Pretend xcodebuild fails w/ exit code 1, and so fbxcodetest should fail.
  testWithExitStatus(1);
}

- (void)testConfigurationIsTakenFromScheme
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj"
                                                     scheme:@"TestProject-Library"
                                               settingsPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"build",
                       @"-reporter", @"plain",
                       ];

    [TestUtil runWithFakeStreams:tool];

    assertThat([[[FakeTaskManager sharedManager] launchedTasks][0] arguments],
               equalTo(@[
                       @"-project", TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"LaunchConfig",
                       @"build",
                       ]));
  }];
}

- (void)testCanBuildProjectWithTargetsThatUseDifferentSDKs
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithWorkspace:TEST_DATA @"ProjectsWithDifferentSDKs/ProjectsWithDifferentSDKs.xcworkspace"
                                                       scheme:@"ProjectsWithDifferentSDKs"
                                                 settingsPath:TEST_DATA @"ProjectsWithDifferentSDKs-ProjectsWithDifferentSDKs-showBuildSettings.txt"],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-workspace", TEST_DATA @"ProjectsWithDifferentSDKs/ProjectsWithDifferentSDKs.xcworkspace",
                       @"-scheme", @"ProjectsWithDifferentSDKs",
                       @"build",
                       @"-reporter", @"plain",
                       ];

    [TestUtil runWithFakeStreams:tool];

    assertThat([[[FakeTaskManager sharedManager] launchedTasks][0] arguments],
               equalTo(@[
                       @"-workspace", TEST_DATA @"ProjectsWithDifferentSDKs/ProjectsWithDifferentSDKs.xcworkspace",
                       @"-scheme", @"ProjectsWithDifferentSDKs",
                       @"-configuration", @"Debug",
                       @"build",
                       ]));
  }];
}

- (void)testDryRunOptionSetsFlag
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithWorkspace:TEST_DATA @"ProjectsWithDifferentSDKs/ProjectsWithDifferentSDKs.xcworkspace"
                                                       scheme:@"ProjectsWithDifferentSDKs"
                                                 settingsPath:TEST_DATA @"ProjectsWithDifferentSDKs-ProjectsWithDifferentSDKs-showBuildSettings.txt"],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-workspace", TEST_DATA @"ProjectsWithDifferentSDKs/ProjectsWithDifferentSDKs.xcworkspace",
                       @"-scheme", @"ProjectsWithDifferentSDKs",
                       @"build",
                       @"-dry-run",
                       @"-reporter", @"plain",
                       ];

    [TestUtil runWithFakeStreams:tool];

    assertThat([[[FakeTaskManager sharedManager] launchedTasks][0] arguments],
               equalTo(@[
                         @"-workspace", TEST_DATA @"ProjectsWithDifferentSDKs/ProjectsWithDifferentSDKs.xcworkspace",
                         @"-scheme", @"ProjectsWithDifferentSDKs",
                         @"-configuration", @"Debug",
                         @"-dry-run",
                         @"build",
                         ]));
  }];
}

- (void)testSkipUnavailableActionsOptionSetsFlag
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithWorkspace:TEST_DATA @"ProjectsWithDifferentSDKs/ProjectsWithDifferentSDKs.xcworkspace"
                                                       scheme:@"ProjectsWithDifferentSDKs"
                                                 settingsPath:TEST_DATA @"ProjectsWithDifferentSDKs-ProjectsWithDifferentSDKs-showBuildSettings.txt"],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-workspace", TEST_DATA @"ProjectsWithDifferentSDKs/ProjectsWithDifferentSDKs.xcworkspace",
                       @"-scheme", @"ProjectsWithDifferentSDKs",
                       @"build",
                       @"-skipUnavailableActions",
                       @"-reporter", @"plain",
                       ];

    [TestUtil runWithFakeStreams:tool];

    assertThat([[[FakeTaskManager sharedManager] launchedTasks][0] arguments],
               equalTo(@[
                         @"-workspace", TEST_DATA @"ProjectsWithDifferentSDKs/ProjectsWithDifferentSDKs.xcworkspace",
                         @"-scheme", @"ProjectsWithDifferentSDKs",
                         @"-configuration", @"Debug",
                         @"-skipUnavailableActions",
                         @"build",
                         ]));
  }];
}

@end
