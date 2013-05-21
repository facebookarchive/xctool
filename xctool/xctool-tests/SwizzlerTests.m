
#import <SenTestingKit/SenTestingKit.h>

#import "Swizzler.h"

@interface SwizzlerTests : SenTestCase
@end

@implementation SwizzlerTests

- (void)testCanSwizzleAndUnswizzleInstanceMethod
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

- (void)testCanSwizzleAndUnswizzleClassMethod
{
  __block int blockCalledCount = 0;
  SwizzleReceipt *receipt =
  [Swizzler swizzleSelector:@selector(string)
                   forClass:[NSString class]
                  withBlock:^(id self, SEL sel) {
                    blockCalledCount++;
                    return @"sentinel";
                  }];

  assertThat([NSString string], equalTo(@"sentinel"));
  assertThatInt(blockCalledCount, equalToInt(1));

  [Swizzler unswizzleFromReceipt:receipt];

  assertThat([NSString string], equalTo(@""));
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

  [Swizzler whileSwizzlingSelector:@selector(string)
                          forClass:[NSString class]
                         withBlock:^(id self, SEL sel){
                           return @"sentinel";
                         }
                          runBlock:^{
                            assertThat([NSString string],
                                       equalTo(@"sentinel"));
                          }];
}

@end
