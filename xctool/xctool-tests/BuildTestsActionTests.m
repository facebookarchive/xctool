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
#import "BuildTestsAction.h"
#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "LaunchHandlers.h"
#import "Options.h"
#import "Options+Testing.h"
#import "TaskUtil.h"
#import "TestUtil.h"
#import "XCTool.h"
#import "XCToolUtil.h"
#import "xcodeSubjectInfo.h"

@interface BuildTestsActionTests : SenTestCase
@end

@implementation BuildTestsActionTests

- (void)setUp
{
  [super setUp];
}

- (void)testOnlyListIsCollected
{
  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator6.1",
                       @"build-tests", @"-only", @"TestProject-LibraryTests",
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  BuildTestsAction *action = options.actions[0];
  assertThat((action.onlyList), equalTo(@[@"TestProject-LibraryTests"]));
}


- (void)testSkipDependenciesIsCollected
{
  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator6.1",
                       @"build-tests", @"-only", @"TestProject-LibraryTests",
                       @"-skip-deps"
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  BuildTestsAction *action = options.actions[0];
  assertThatBool(action.skipDependencies, equalToBool(YES));
}

- (void)testOnlyListRequiresValidTarget
{
  [[Options optionsFrom:@[
    @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
    @"-scheme", @"TestProject-Library",
    @"-sdk", @"iphonesimulator6.1",
    @"build-tests", @"-only", @"BOGUS_TARGET",
    ]]
   assertOptionsFailToValidateWithError:
   @"build-tests: 'BOGUS_TARGET' is not a testing target in this scheme."
   withBuildSettingsFromFile:
   TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
   ];
}

- (void)testBuildTestsAction
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"
                                                     scheme:@"TestProject-Library"
                                               settingsPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"],
     ]];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"build-tests"
                       ];

    [TestUtil runWithFakeStreams:tool];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(2));
    assertThat([launchedTasks[0] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-target", @"TestProject-Library",
                       @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates",
                       @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates/PrecompiledHeaders",
                       @"build",
                       ]));
    assertThat([launchedTasks[1] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-target", @"TestProject-LibraryTests",
                       @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates",
                       @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates/PrecompiledHeaders",
                       @"build",
                       ]));
    assertThatInt(tool.exitStatus, equalToInt(0));
  }];
}

- (void)testBuildTestsActionWillBuildEverythingMarkedAsBuildForTest
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithWorkspace:TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace"
                                                       scheme:@"TestProject-Library"
                                                 settingsPath:TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"],
     ]];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[
                       @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"build-tests"
                       ];

    [TestUtil runWithFakeStreams:tool];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(4));
    assertThat([launchedTasks[0] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"-project", TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj",
                       @"-target", @"TestProject-Library",
                       @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates",
                       @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates/PrecompiledHeaders",
                       @"build"
                       ]));
    assertThat([launchedTasks[1] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"-project", TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj",
                       @"-target", @"TestProject-OtherLib",
                       @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates",
                       @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates/PrecompiledHeaders",
                       @"build",
                       ]));
    assertThat([launchedTasks[2] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"-project", TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj",
                       @"-target", @"TestProject-LibraryTests",
                       @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates",
                       @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates/PrecompiledHeaders",
                       @"build",
                       ]));
    assertThat([launchedTasks[3] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"-project", TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj",
                       @"-target", @"TestProject-LibraryTests2",
                       @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates",
                       @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates/PrecompiledHeaders",
                       @"build",
                       ]));
    assertThatInt(tool.exitStatus, equalToInt(0));
  }];
}

- (void)testBuildTestsCanBuildASingleTarget
{
  // In TestWorkspace-Library, we have a target TestProject-LibraryTest2 that depends on
  // TestProject-OtherLib, but it isn't marked as an explicit dependency.  The only way that
  // dependency gets built is that it's added to the scheme as build-for-test above
  // TestProject-LibraryTest2.  This a lame way to setup dependencies (they should be explicit),
  // but we're seeing this in the wild and should support it.
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithWorkspace:TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace"
                                                       scheme:@"TestProject-Library"
                                                 settingsPath:TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"],
     ]];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[
                       @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"build-tests", @"-only", @"TestProject-LibraryTests"
                       ];

    [TestUtil runWithFakeStreams:tool];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(3));
    assertThat([launchedTasks[0] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"-project", TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj",
                       @"-target", @"TestProject-Library",
                       @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates",
                       @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates/PrecompiledHeaders",
                       @"build",
                       ]));
    assertThat([launchedTasks[1] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"-project", TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj",
                       @"-target", @"TestProject-OtherLib",
                       @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates",
                       @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates/PrecompiledHeaders",
                       @"build",
                       ]));
    assertThat([launchedTasks[2] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"-project", TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj",
                       @"-target", @"TestProject-LibraryTests",
                       @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates",
                       @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates/PrecompiledHeaders",
                       @"build",
                       ]));
    assertThatInt(tool.exitStatus, equalToInt(0));
  }];
}


- (void)testSkipDependencies
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithWorkspace:TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace"
                                                       scheme:@"TestProject-Library"
                                                 settingsPath:TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"],
     ]];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[
                       @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"build-tests",
                       @"-only", @"TestProject-LibraryTests",
                       @"-skip-deps"
                       ];

    [TestUtil runWithFakeStreams:tool];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(1));
    assertThat([launchedTasks[0] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"-project", TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj",
                       @"-target", @"TestProject-LibraryTests",
                       @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates",
                       @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates/PrecompiledHeaders",
                       @"build",
                       ]));
    assertThatInt(tool.exitStatus, equalToInt(0));
  }];
}

@end
