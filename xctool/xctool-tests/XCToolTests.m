
#import <SenTestingKit/SenTestingKit.h>

#import "FakeTask.h"
#import "TaskUtil.h"
#import "TestUtil.h"
#import "XCTool.h"
#import "XCToolUtil.h"

@interface XCToolTests : SenTestCase
@end

@implementation XCToolTests

- (void)setUp
{
  [super setUp];
  SetTaskInstanceBlock(nil);
  ReturnFakeTasks(nil);
}

- (void)tearDown
{
  [super tearDown];
}

- (void)testCallingWithHelpPrintsUsage
{
  XCTool *tool = [[[XCTool alloc] init] autorelease];
  tool.arguments = @[@"-help"];

  NSDictionary *result = [TestUtil runWithFakeStreams:tool];

  assertThatInt(tool.exitStatus, equalToInt(1));
  assertThat((result[@"stderr"]), startsWith(@"usage: xctool"));
}

- (void)testCallingWithNoArgsDefaultsToBuild
{
  XCTool *tool = [[[XCTool alloc] init] autorelease];
  tool.arguments = @[];

  NSDictionary *result = [TestUtil runWithFakeStreams:tool];

  assertThatInt(tool.exitStatus, equalToInt(1));
  assertThat((result[@"stderr"]), startsWith(@"ERROR:"));
}

- (void)testCallingWithShowBuildSettingsPassesThroughToXcodebuild
{
  NSArray *fakeTasks = @[[FakeTask fakeTaskWithExitStatus:0
                                       standardOutputPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"
                                        standardErrorPath:nil],
                         ];

  XCTool *tool = [[[XCTool alloc] init] autorelease];
  ReturnFakeTasks(fakeTasks);

  tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"-showBuildSettings",
                     ];

  NSDictionary *output = [TestUtil runWithFakeStreams:tool];

  assertThat(([fakeTasks[0] arguments]),
             equalTo(@[
                     @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"-showBuildSettings",
                     ]));
  assertThat(output[@"stdout"], startsWith(@"Build settings"));
}

@end
