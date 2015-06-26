//
// Copyright 2004-present Facebook. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <XCTest/XCTest.h>

#import "Swizzler.h"

@interface SwizzlerTests : XCTestCase
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
