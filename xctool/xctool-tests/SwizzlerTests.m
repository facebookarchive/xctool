
#import <SenTestingKit/SenTestingKit.h>

#import "Swizzler.h"

@interface SwizzlerTests : SenTestCase
@end

@implementation SwizzlerTests

- (void)testCanSwizzleAndUnswizzleMethod
{
  NSString *str = @"Hello!";
  __block int blockCalledCount = 0;

  SwizzleReceipt *receipt =
    [Swizzler swizzleSelector:@selector(lowercaseString)
          forInstancesOfClass:[NSString class]
                    withBlock:
     ^(id self, SEL sel){
       blockCalledCount++;
       // We're going to make it return upper case instead!
       return [self uppercaseString];
     }];

  // Should increment our counter just once!
  assertThat([str lowercaseString], equalTo(@"HELLO!"));
  assertThatInt(blockCalledCount, equalToInt(1));

  // Then replace the original implementation.
  [Swizzler unswizzleFromReceipt:receipt];

  // Should still be one!
  assertThat([str lowercaseString], equalTo(@"hello!"));
  assertThatInt(blockCalledCount, equalToInt(1));
}

- (void)testWhileSwizzlingHelperWorks
{
  [Swizzler whileSwizzlingSelector:@selector(lowercaseString)
               forInstancesOfClass:[NSString class]
                         withBlock:^(id self, SEL sel){
                           return [self uppercaseString];
                         }
                          runBlock:^{
                            assertThat([@"Hello!" lowercaseString],
                                       equalTo(@"HELLO!"));
                          }];
}

@end
