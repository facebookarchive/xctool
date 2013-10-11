
#import <SenTestingKit/SenTestingKit.h>

#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "LaunchHandlers.h"
#import "TestUtil.h"
#import "XCTool.h"

@interface ArchiveActionTests : SenTestCase
@end

@implementation ArchiveActionTests

- (void)testArchiveActionTriggersBuildForProjectAndScheme
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"
                                                     scheme:@"TestProject-Library"
                                               settingsPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"],
     ]];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"archive",
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
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-App-OSX/TestProject-App-OSX.xcodeproj"
                                                     scheme:@"TestProject-App-OSX"
                                               settingsPath:TEST_DATA @"TestProject-App-OSX-showBuildSettings.txt"],
     [[^(FakeTask *task){
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
    } copy] autorelease],
     ]];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-App-OSX/TestProject-App-OSX.xcodeproj",
                       @"-scheme", @"TestProject-App-OSX",
                       @"archive",
                       ];

    NSDictionary *output = [TestUtil runWithFakeStreams:tool];

    assertThatInt([tool exitStatus], equalToInt(1));
    assertThat(output[@"stdout"], containsString(@"** ARCHIVE FAILED **"));
  }];
}

- (void)testArchiveWithAllPassingCommandsShouldSucceed
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-App-OSX/TestProject-App-OSX.xcodeproj"
                                                     scheme:@"TestProject-App-OSX"
                                               settingsPath:TEST_DATA @"TestProject-App-OSX-showBuildSettings.txt"],
     [[^(FakeTask *task){
      if ([[task launchPath] hasSuffix:@"xcodebuild"] &&
          [[task arguments] containsObject:@"archive"])
      {
        [task pretendTaskReturnsStandardOutput:
         [NSString stringWithContentsOfFile:TEST_DATA @"xcodebuild-archive-good.txt"
                                   encoding:NSUTF8StringEncoding
                                      error:nil]];
        [task pretendExitStatusOf:0];
      }
    } copy] autorelease],
     ]];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-App-OSX/TestProject-App-OSX.xcodeproj",
                       @"-scheme", @"TestProject-App-OSX",
                       @"archive",
                       ];

    NSDictionary *output = [TestUtil runWithFakeStreams:tool];

    assertThatInt([tool exitStatus], equalToInt(0));
    assertThat(output[@"stdout"], containsString(@"** ARCHIVE SUCCEEDED **"));
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
     ]];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"archive",
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
