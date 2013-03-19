
#import <SenTestingKit/SenTestingKit.h>
#import "XcodeTool.h"
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

@end
