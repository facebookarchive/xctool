#import "TaskUtil.h"
#import "FakeTask.h"
#import <SenTestingKit/SenTestingKit.h>

@interface TaskUtilTests : SenTestCase
@end

@implementation TaskUtilTests

- (void)testLaunchTaskAndFeedOutputLinesToBlockMultibyteUtf8
{
  // Construct a large (> buffer size) stdout consisting of multibyte unicode
  // characters, once with 0 offset, and once with 1 offset (to ensure that any
  // buffer splitting won't get lucky and end up at a character boundary)

  const NSInteger lineLength = 1024*1024;

  NSString *multibyteChar = @"\U00010196"; // ROMAN DENARIUS SIGN
  NSString *longLine = [@"" stringByPaddingToLength:lineLength withString:multibyteChar startingAtIndex:0];
  
  NSString *fakeInput1 = [NSString stringWithFormat:@"%@\n%@\n%@\n", longLine, longLine, longLine];
  NSString *fakeInput2 = [@"a" stringByAppendingString:fakeInput1];
  
  for (NSString *fakeInput in @[fakeInput1, fakeInput2]) {
    FakeTask *fakeTask = (FakeTask *)[FakeTask fakeTaskWithExitStatus:0];
    [fakeTask pretendTaskReturnsStandardOutput:fakeInput];

    __block int lineCount = 0;
    LaunchTaskAndFeedOuputLinesToBlock(fakeTask, @"test", ^(NSString *str) {
      if ([str hasPrefix:@"a"]) {
        str = [str substringFromIndex:1];
      }
      STAssertTrue([str isEqualToString:longLine], @"output lines should be equal to input lines");
      lineCount++;
    });
    STAssertEquals(lineCount, 3, @"should have emitted 3 lines");
  }
}

@end

