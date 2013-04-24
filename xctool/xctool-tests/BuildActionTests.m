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
#import "Options.h"
#import "TaskUtil.h"
#import "TestUtil.h"
#import "XCToolUtil.h"
#import "xcodeSubjectInfo.h"

@interface BuildActionTests : SenTestCase
@end

@implementation BuildActionTests

- (void)setUp
{
  [super setUp];
  SetTaskInstanceBlock(nil);
  ReturnFakeTasks(nil);
}

- (void)testBuildActionPassesSDKParamToXcodebuild
{
  NSArray *fakeTasks = @[[FakeTask fakeTaskWithExitStatus:0
                                           standardOutputPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"
                                            standardErrorPath:nil],
                         [[[FakeTask alloc] init] autorelease],
                         ];

  XCTool *tool = [[[XCTool alloc] init] autorelease];
  ReturnFakeTasks(fakeTasks);

  tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"-sdk", @"iphonesimulator6.0",
                     @"build",
                     ];

  [TestUtil runWithFakeStreams:tool];

  assertThat([fakeTasks[1] arguments],
             equalTo(@[
                     @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"-configuration", @"Debug",
                     @"-sdk", @"iphonesimulator6.0",
                     @"build",
                     ]));
}

- (void)testBuildActionTriggersBuildForProjectAndScheme
{
  NSArray *fakeTasks = @[[FakeTask fakeTaskWithExitStatus:0
                                           standardOutputPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"
                                            standardErrorPath:nil],
                         [[[FakeTask alloc] init] autorelease],
                         ];

  XCTool *tool = [[[XCTool alloc] init] autorelease];
  ReturnFakeTasks(fakeTasks);

  tool.arguments = @[
                     @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"build",
                     ];

  [TestUtil runWithFakeStreams:tool];

  assertThat([fakeTasks[1] arguments],
             equalTo(@[
                     @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"-configuration", @"Debug",
                     @"-sdk", @"iphonesimulator6.0",
                     @"build",
                     ]));
}

- (void)testBuildActionTriggersBuildForWorkspaceAndScheme
{
  NSArray *fakeTasks = @[[FakeTask fakeTaskWithExitStatus:0
                                           standardOutputPath:TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"
                                            standardErrorPath:nil],
                         [[[FakeTask alloc] init] autorelease],
                         ];

  XCTool *tool = [[[XCTool alloc] init] autorelease];
  ReturnFakeTasks(fakeTasks);

  tool.arguments = @[@"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                     @"-scheme", @"TestProject-Library",
                     @"build",
                     ];

  [TestUtil runWithFakeStreams:tool];

  assertThat([fakeTasks[1] arguments],
             equalTo(@[
                     @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                     @"-scheme", @"TestProject-Library",
                     @"-configuration", @"Debug",
                     @"-sdk", @"iphonesimulator6.0",
                     @"build",
                     ]));
}

- (void)testBuildActionPassesConfigurationParamToXcodebuild
{
  NSArray *fakeTasks = @[[FakeTask fakeTaskWithExitStatus:0
                                           standardOutputPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"
                                            standardErrorPath:nil],
                         [[[FakeTask alloc] init] autorelease],
                         ];

  XCTool *tool = [[[XCTool alloc] init] autorelease];
  ReturnFakeTasks(fakeTasks);

  tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"-configuration", @"SOME_CONFIGURATION",
                     @"build",
                     ];

  [TestUtil runWithFakeStreams:tool];

  assertThat(([fakeTasks[1] arguments]),
             equalTo(@[
                     @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"-configuration", @"SOME_CONFIGURATION",
                     @"-sdk", @"iphonesimulator6.0",
                     @"build",
                     ]));
}

- (void)testIfBuildActionFailsThenExitStatusShouldBeOne
{
  void (^testWithExitStatus)(int) = ^(int exitStatus) {
    NSArray *fakeTasks = @[[FakeTask fakeTaskWithExitStatus:0
                                             standardOutputPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"
                                              standardErrorPath:nil],
                           // This exit status should get returned...
                           [FakeTask fakeTaskWithExitStatus:exitStatus],
                           ];

    XCTool *tool = [[[XCTool alloc] init] autorelease];
    ReturnFakeTasks(fakeTasks);

    tool.arguments = @[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"build",
                       ];

    [TestUtil runWithFakeStreams:tool];

    assertThatInt(tool.exitStatus, equalToInt(exitStatus));
  };

  // Pretend xcodebuild succeeds, and so we should succeed.
  testWithExitStatus(0);
  // Pretend xcodebuild fails w/ exit code 1, and so fbxcodetest should fail.
  testWithExitStatus(1);
}

@end
