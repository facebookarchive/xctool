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

#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "LaunchHandlers.h"
#import "TestUtil.h"
#import "XCTool.h"

@interface ArchiveActionTests : XCTestCase
@end

@implementation ArchiveActionTests

- (void)testArchiveActionTriggersBuildForProjectAndScheme
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
                       @"archive",
                       @"-reporter", @"plain",
                       ];

    [TestUtil runWithFakeStreams:tool];

    assertThat([[[FakeTaskManager sharedManager] launchedTasks][0] arguments],
               equalTo(@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Release",
                       @"archive",
                       ]));
  }];
}

- (void)testArchiveWithFailingCommandShouldFail
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-App-OSX/TestProject-App-OSX.xcodeproj"
                                                     scheme:@"TestProject-App-OSX"
                                               settingsPath:TEST_DATA @"TestProject-App-OSX-showBuildSettings.txt"],
     [^(FakeTask *task){
      if ([[task launchPath] hasSuffix:@"xcodebuild"] &&
          [[task arguments] containsObject:@"archive"])
      {
        [task pretendTaskReturnsStandardOutput:
         [NSString stringWithContentsOfFile:TEST_DATA @"xcodebuild-archive-bad.txt"
                                   encoding:NSUTF8StringEncoding
                                      error:nil]];
        // Even when archive fails, 'xcodebuild' returns zero.
        [task pretendExitStatusOf:0];
      }
    } copy],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-App-OSX/TestProject-App-OSX.xcodeproj",
                       @"-scheme", @"TestProject-App-OSX",
                       @"archive",
                       @"-reporter", @"plain",
                       ];

    NSDictionary *output = [TestUtil runWithFakeStreams:tool];

    assertThatInt([tool exitStatus], equalToInt(1));
    assertThat(output[@"stdout"], containsString(@"** ARCHIVE FAILED **"));
  }];
}

- (void)testArchiveWithAllPassingCommandsShouldSucceed
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-App-OSX/TestProject-App-OSX.xcodeproj"
                                                     scheme:@"TestProject-App-OSX"
                                               settingsPath:TEST_DATA @"TestProject-App-OSX-showBuildSettings.txt"],
     [^(FakeTask *task){
      if ([[task launchPath] hasSuffix:@"xcodebuild"] &&
          [[task arguments] containsObject:@"archive"])
      {
        [task pretendTaskReturnsStandardOutput:
         [NSString stringWithContentsOfFile:TEST_DATA @"xcodebuild-archive-good.txt"
                                   encoding:NSUTF8StringEncoding
                                      error:nil]];
        [task pretendExitStatusOf:0];
      }
    } copy],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-App-OSX/TestProject-App-OSX.xcodeproj",
                       @"-scheme", @"TestProject-App-OSX",
                       @"archive",
                       @"-reporter", @"plain",
                       ];

    NSDictionary *output = [TestUtil runWithFakeStreams:tool];

    assertThatInt([tool exitStatus], equalToInt(0));
    assertThat(output[@"stdout"], containsString(@"** ARCHIVE SUCCEEDED **"));
  }];
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
                       @"archive",
                       @"-reporter", @"plain",
                       ];

    [TestUtil runWithFakeStreams:tool];

    assertThat([[[FakeTaskManager sharedManager] launchedTasks][0] arguments],
               equalTo(@[
                       @"-project", TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"ArchiveConfig",
                       @"archive",
                       ]));
  }];
}

@end
