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

#import "TaskUtil.h"
#import "FakeTask.h"
#import <XCTest/XCTest.h>

@interface TaskUtilTests : XCTestCase
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
      XCTAssertTrue([str isEqualToString:longLine], @"output lines should be equal to input lines");
      lineCount++;
    });
    XCTAssertEqual(lineCount, 3, @"should have emitted 3 lines");
  }
}

@end
