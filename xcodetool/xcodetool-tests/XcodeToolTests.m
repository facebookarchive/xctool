
#import <SenTestingKit/SenTestingKit.h>
#import "FBXcodeTool.h"
#import "Functions.h"
#import "Fakes.h"
#import "TestUtil.h"

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
  FBXcodeTool *tool = [[[FBXcodeTool alloc] init] autorelease];
  tool.arguments = @[@"-help"];
  
  NSDictionary *result = [TestUtil runWithFakeStreams:tool];
  
  assertThatInt(tool.exitStatus, equalToInt(1));
  assertThat((result[@"stderr"]), startsWith(@"usage: xcodetool"));
}

- (void)testCallingWithNoArgsDefaultsToBuild
{
  FBXcodeTool *tool = [[[FBXcodeTool alloc] init] autorelease];
  tool.arguments = @[];
  
  NSDictionary *result = [TestUtil runWithFakeStreams:tool];
  
  assertThatInt(tool.exitStatus, equalToInt(1));
  assertThat((result[@"stderr"]), startsWith(@"ERROR:"));
}

@end
