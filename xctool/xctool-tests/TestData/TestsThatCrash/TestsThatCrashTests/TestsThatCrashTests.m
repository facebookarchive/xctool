
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

- (void)testExample1
{

}

- (void)testExample2Fails
{
  STFail(@"Failing test");
}

- (void)testExample3
{

}

- (void)testExample4Crashes
{
  printf("Hello!\n");
  abort();
}

- (void)testExample5
{

}

- (void)testExample6
{

}

- (void)testExample7
{

}

- (void)testExample8
{
  
}

@end
