
#import <SenTestingKit/SenTestingKit.h>

@interface TestsThatCrashTests : SenTestCase

@end

@implementation TestsThatCrashTests

- (void)setUp
{
    [super setUp];

    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.

    [super tearDown];
}

- (void)testThatCrashes
{
  printf("Hello!\n");
  abort();
}

@end
