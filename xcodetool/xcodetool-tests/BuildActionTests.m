
#import <SenTestingKit/SenTestingKit.h>
#import "Action.h"
#import "BuildTestInfo.h"
#import "ImplicitAction.h"
#import "Fakes.h"
#import "Functions.h"
#import "Options.h"
#import "TestUtil.h"

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
  NSArray *fakeTasks = @[[TestUtil fakeTaskWithExitStatus:0
                                           standardOutput:[NSString stringWithContentsOfFile:TEST_DATA @"TestProject-Library-showBuildSettings.txt" encoding:NSUTF8StringEncoding error:nil]
                                            standardError:@""],
                         [[[FakeTask alloc] init] autorelease],
                         ];
  
  FBXcodeTool *tool = [[[FBXcodeTool alloc] init] autorelease];
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
  NSArray *fakeTasks = @[[TestUtil fakeTaskWithExitStatus:0
                                           standardOutput:[NSString stringWithContentsOfFile:TEST_DATA @"TestProject-Library-showBuildSettings.txt" encoding:NSUTF8StringEncoding error:nil]
                                            standardError:@""],
                         [[[FakeTask alloc] init] autorelease],
                         ];
  
  FBXcodeTool *tool = [[[FBXcodeTool alloc] init] autorelease];
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
  NSArray *fakeTasks = @[[TestUtil fakeTaskWithExitStatus:0
                                           standardOutput:[NSString stringWithContentsOfFile:TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt" encoding:NSUTF8StringEncoding error:nil]
                                            standardError:@""],
                         [[[FakeTask alloc] init] autorelease],
                         ];
  
  FBXcodeTool *tool = [[[FBXcodeTool alloc] init] autorelease];
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
  NSArray *fakeTasks = @[[TestUtil fakeTaskWithExitStatus:0
                                           standardOutput:[NSString stringWithContentsOfFile:TEST_DATA @"TestProject-Library-showBuildSettings.txt" encoding:NSUTF8StringEncoding error:nil]
                                            standardError:@""],
                         [[[FakeTask alloc] init] autorelease],
                         ];
  
  FBXcodeTool *tool = [[[FBXcodeTool alloc] init] autorelease];
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
    NSArray *fakeTasks = @[[TestUtil fakeTaskWithExitStatus:0
                                             standardOutput:[NSString stringWithContentsOfFile:TEST_DATA @"TestProject-Library-showBuildSettings.txt" encoding:NSUTF8StringEncoding error:nil]
                                              standardError:@""],
                           // This exit status should get returned...
                           [TestUtil fakeTaskWithExitStatus:exitStatus],
                           ];
    
    FBXcodeTool *tool = [[[FBXcodeTool alloc] init] autorelease];
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
