
#import <SenTestingKit/SenTestingKit.h>

#import "Fakes.h"
#import "TaskUtil.h"
#import "TestUtil.h"
#import "XcodeTool.h"
#import "XcodeToolUtil.h"

@interface XcodeToolTests : SenTestCase
@end

@implementation XcodeToolTests

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
  XcodeTool *tool = [[[XcodeTool alloc] init] autorelease];
  tool.arguments = @[@"-help"];
  
  NSDictionary *result = [TestUtil runWithFakeStreams:tool];
  
  assertThatInt(tool.exitStatus, equalToInt(1));
  assertThat((result[@"stderr"]), startsWith(@"usage: xcodetool"));
}

- (void)testCallingWithNoArgsDefaultsToBuild
{
  XcodeTool *tool = [[[XcodeTool alloc] init] autorelease];
  tool.arguments = @[];
  
  NSDictionary *result = [TestUtil runWithFakeStreams:tool];
  
  assertThatInt(tool.exitStatus, equalToInt(1));
  assertThat((result[@"stderr"]), startsWith(@"ERROR:"));
}

- (void)testCallingWithShowBuildSettingsPassesThroughToXcodebuild
{
  NSArray *fakeTasks = @[[TestUtil fakeTaskWithExitStatus:0
                                           standardOutput:[NSString stringWithContentsOfFile:TEST_DATA @"TestProject-Library-showBuildSettings.txt" encoding:NSUTF8StringEncoding error:nil]
                                            standardError:@""],
                         ];

  XcodeTool *tool = [[[XcodeTool alloc] init] autorelease];
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
