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

#import <objc/message.h>
#import <objc/runtime.h>

#import <XCTest/XCTest.h>

#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"

@interface FakeTaskManagerTests : XCTestCase
@end

@implementation FakeTaskManagerTests

- (void)testCanRunRealTasks
{
  NSTask *task = CreateTaskInSameProcessGroup();
  [task setLaunchPath:@"/bin/echo"];
  [task setArguments:@[@"hello"]];

  NSDictionary *output = LaunchTaskAndCaptureOutput(task,
                                                    @"some description");
  assertThat(output[@"stdout"], equalTo(@"hello\n"));
}

- (void)testCanMakeAllTasksFake
{
  [[FakeTaskManager sharedManager] enableFakeTasks];
  NSTask *task = CreateTaskInSameProcessGroup();
  assertThat([[task class] description], equalTo(@"FakeTask"));
  [[FakeTaskManager sharedManager] disableFakeTasks];
}

- (void)testCanGetPretendStandardOutput
{
  [[FakeTaskManager sharedManager] enableFakeTasks];
  NSTask *task = CreateTaskInSameProcessGroup();
  [task setLaunchPath:@"/bin/something"];
  [(FakeTask *)task pretendTaskReturnsStandardOutput:@"some stdout string"];
  assertThat(LaunchTaskAndCaptureOutput(task, @"some description")[@"stdout"],
             equalTo(@"some stdout string"));
  [[FakeTaskManager sharedManager] disableFakeTasks];
}

- (void)testCanGetPretendStandardError
{
  [[FakeTaskManager sharedManager] enableFakeTasks];
  NSTask *task = CreateTaskInSameProcessGroup();
  [task setLaunchPath:@"/bin/something"];
  [(FakeTask *)task pretendTaskReturnsStandardError:@"some stderr string"];
  assertThat(LaunchTaskAndCaptureOutput(task, @"some description")[@"stderr"],
             equalTo(@"some stderr string"));
  [[FakeTaskManager sharedManager] disableFakeTasks];
}

- (void)testCanGetPretendExitStatus
{
  [[FakeTaskManager sharedManager] enableFakeTasks];
  NSTask *task = CreateTaskInSameProcessGroup();
  [task setLaunchPath:@"/bin/something"];
  [(FakeTask *)task pretendExitStatusOf:5];
  [task launch];
  [task waitUntilExit];
  assertThatInt([task terminationStatus], equalToInt(5));
  [[FakeTaskManager sharedManager] disableFakeTasks];
}

- (void)testLaunchedTasksAreRecorded
{
  [[FakeTaskManager sharedManager] enableFakeTasks];
  NSTask *task1 = CreateTaskInSameProcessGroup();
  [task1 setLaunchPath:@"/bin/echo"];
  [task1 setArguments:@[@"task1"]];
  [task1 launch];
  [task1 waitUntilExit];

  NSTask *task2 = CreateTaskInSameProcessGroup();
  [task2 setLaunchPath:@"/bin/echo"];
  [task2 setArguments:@[@"task2"]];
  [task2 launch];
  [task2 waitUntilExit];

  NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
  assertThatInteger([launchedTasks count], equalToInteger(2));
  assertThat([launchedTasks[0] arguments], equalTo(@[@"task1"]));
  assertThat([launchedTasks[1] arguments], equalTo(@[@"task2"]));

  [[FakeTaskManager sharedManager] disableFakeTasks];
}

- (void)testRunBlockWithFakeTasksWorks
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    NSTask *task1 = CreateTaskInSameProcessGroup();
    [task1 setLaunchPath:@"/bin/echo"];
    [task1 setArguments:@[@"task1"]];
    [task1 launch];
    [task1 waitUntilExit];

    assertThatInteger([[[FakeTaskManager sharedManager] launchedTasks] count],
                      equalToInteger(1));
  }];
}

- (void)testRunBlockWithFakeTasksPropagatesExceptionsAndDisablesFakeTasks
{
  @try {
    [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      assertThatBool([[FakeTaskManager sharedManager] fakeTasksAreEnabled],
                     isTrue());

      [NSException raise:NSGenericException format:@"An exception."];
    }];
  }
  @catch (NSException *exception) {
    assertThat([exception reason], equalTo(@"An exception."));
  }
  @finally {
  }

  // runBlockWithFakeTasks: should still make sure fake tasks get disabled when
  // the block finishes, even if there is an exception.
  assertThatBool([[FakeTaskManager sharedManager] fakeTasksAreEnabled],
                 isFalse());
}

- (void)testCanSetLaunchHandlerBlocksToTickleFakeTasks
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    // These blocks will get called at the top of -[FakeTask launch].
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     ^(FakeTask *task){
      [task pretendTaskReturnsStandardOutput:@"some stdout!"];
    },
     ]];

    NSTask *task = CreateTaskInSameProcessGroup();
    [task setLaunchPath:@"/bin/echo"];
    [task setArguments:@[@"task1"]];
    [task launch];
    [task waitUntilExit];

    assertThat(LaunchTaskAndCaptureOutput(task, @"some description")[@"stdout"],
               equalTo(@"some stdout!"));
  }];
}

/**
 * Our list of default launch handlers should sufficiently fake out the
 * boring NSTask invocations in our code.  These are things we don't care to
 * see when writing most of our tests.
 */
- (void)testDefaultLaunchHandlers
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    // This function calls out to xcode-select
    NSString *path = XcodeDeveloperDirPath();
    assertThat(path, equalTo(@"/Applications/Xcode.app/Contents/Developer"));

    // This function calls out to xcodebuild -showsdks
    NSDictionary *sdksAndAliases = GetAvailableSDKsAndAliases();
    assertThat(sdksAndAliases,
               equalTo(@{
      @"iphoneos" : @"iphoneos6.1",
      @"iphoneos6.1" : @"iphoneos6.1",
      @"iphonesimulator" : @"iphonesimulator6.1",
      @"iphonesimulator5.0" : @"iphonesimulator5.0",
      @"iphonesimulator5.1" : @"iphonesimulator5.1",
      @"iphonesimulator6.0" : @"iphonesimulator6.0",
      @"iphonesimulator6.1" : @"iphonesimulator6.1",
      @"macosx" : @"macosx10.8",
      @"macosx10.7" : @"macosx10.7",
      @"macosx10.8" : @"macosx10.8",
      @"appletvsimulator": @"appletvsimulator9.1",
      @"appletvsimulator9.1": @"appletvsimulator9.1",
      @"watchos": @"watchos2.1",
      @"watchos2.1": @"watchos2.1",
      @"watchsimulator": @"watchsimulator2.1",
      @"watchsimulator2.1": @"watchsimulator2.1",
      @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.7.sdk": @"macosx10.7",
      @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk": @"macosx10.8",
      @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS6.1.sdk": @"iphoneos6.1",
      @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.1.sdk": @"iphonesimulator5.1",
      @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator6.0.sdk": @"iphonesimulator6.0",
      @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator6.1.sdk": @"iphonesimulator5.0",
      @"/Applications/Xcode.app/Contents/Developer/Platforms/AppleTVSimulator.platform/Developer/SDKs/AppleTVSimulator9.1.sdk": @"appletvsimulator9.1",
      @"/Applications/Xcode.app/Contents/Developer/Platforms/WatchOS.platform/Developer/SDKs/WatchOS2.1.sdk": @"watchos2.1",
      @"/Applications/Xcode.app/Contents/Developer/Platforms/WatchSimulator.platform/Developer/SDKs/WatchSimulator2.1.sdk": @"watchsimulator2.1",
    }));

    // Both of the above should be in the allLaunchedTasks list.  Since XcodeDeveloperDirPath()
    // is called by GetAvailableSDKsAndAliases(), it will show up twice.
    assertThatInteger([[[FakeTaskManager sharedManager] allLaunchedTasks] count],
                      equalToInteger(3));

    // But, not in the 'launchedTasks' list.  The launch handler should have
    // hidden them.
    assertThatInteger([[[FakeTaskManager sharedManager] launchedTasks] count],
                      equalToInteger(0));

  }
                               withDefaultLaunchHandlers:YES];
}

@end
