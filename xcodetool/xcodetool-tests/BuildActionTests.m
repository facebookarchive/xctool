
#import <SenTestingKit/SenTestingKit.h>

#import "Action.h"
#import "FakeTask.h"
#import "Options.h"
#import "TaskUtil.h"
#import "TestUtil.h"
#import "XcodeToolUtil.h"
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

  XcodeTool *tool = [[[XcodeTool alloc] init] autorelease];
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

  XcodeTool *tool = [[[XcodeTool alloc] init] autorelease];
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

  XcodeTool *tool = [[[XcodeTool alloc] init] autorelease];
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

  XcodeTool *tool = [[[XcodeTool alloc] init] autorelease];
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

    XcodeTool *tool = [[[XcodeTool alloc] init] autorelease];
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
