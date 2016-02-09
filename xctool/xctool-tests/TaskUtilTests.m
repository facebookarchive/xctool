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

- (void)testStripAnsi
{
  // test inputs are based on the information listed on http://ascii-table.com/ansi-escape-sequences.php
  XCTAssertEqualObjects(@"test 1", StripAnsi(@"\e[0;1Htest 1"), @"ASCI Escape sequence: Esc[Line;ColumnH");
  XCTAssertEqualObjects(@"test 2", StripAnsi(@"\e[0;1ftest 2"), @"ASCI Escape sequence: Esc[Line;Columnf");
  XCTAssertEqualObjects(@"test 3", StripAnsi(@"\e[22Atest 3"), @"ASCI Escape sequence: Esc[ValueA");
  XCTAssertEqualObjects(@"test 4", StripAnsi(@"\e[30Btest 4"), @"ASCI Escape sequence: Esc[ValueB");
  XCTAssertEqualObjects(@"test 5", StripAnsi(@"\e[4Ctest 5"), @"ASCI Escape sequence: Esc[ValueC");
  XCTAssertEqualObjects(@"test 6", StripAnsi(@"\e[5Dtest 6"), @"ASCI Escape sequence: Esc[ValueD");
  XCTAssertEqualObjects(@"test 7", StripAnsi(@"\e[stest 7"), @"ASCI Escape sequence: Esc[s");
  XCTAssertEqualObjects(@"test 8", StripAnsi(@"\e[utest 8"), @"ASCI Escape sequence: Esc[u");
  XCTAssertEqualObjects(@"test 9", StripAnsi(@"\e[2Jtest 9"), @"ASCI Escape sequence: Esc[2J");
  XCTAssertEqualObjects(@"test 10", StripAnsi(@"\e[Ktest 10"), @"ASCI Escape sequence: Esc[K");
  XCTAssertEqualObjects(@"test 11", StripAnsi(@"\e[1;31mtest 11"), @"ASCI Escape sequence: Esc[Value;...;Valuem");
  XCTAssertEqualObjects(@"test 12", StripAnsi(@"\e[1;31;42mtest 12"), @"ASCI Escape sequence: Esc[Value;...;Valuem");
  XCTAssertEqualObjects(@"test 13", StripAnsi(@"\e[=1htest 13"), @"ASCI Escape sequence: Esc[=Valueh");
  XCTAssertEqualObjects(@"test 14", StripAnsi(@"\e[=1Itest 14"), @"ASCI Escape sequence: Esc[=ValueI");
  XCTAssertEqualObjects(@"test 15", StripAnsi(@"\e[mtest 15"), @"ASCI Escape sequence: Esc[m");

  // not stripped
  XCTAssertEqualObjects(@"\e[0;59;string;ptest 16", StripAnsi(@"\e[0;59;string;ptest 16"), @"ASCI Escape sequence: Esc[Code;String;...p");
  XCTAssertEqualObjects(@"\e[22;2Atest 3", StripAnsi(@"\e[22;2Atest 3"), @"ASCI Escape sequence: Esc[ValueA");
  XCTAssertEqualObjects(@"\e[2utest 8", StripAnsi(@"\e[2utest 8"), @"ASCI Escape sequence: Esc[u");
  XCTAssertEqualObjects(@"\e[=1Ktest 13", StripAnsi(@"\e[=1Ktest 13"), @"ASCI Escape sequence: Esc[=Valueh");
  XCTAssertEqualObjects(@"\e[=htest 13", StripAnsi(@"\e[=htest 13"), @"ASCI Escape sequence: Esc[=Valueh");
}

- (void)testLaunchTaskAndFeedOutputLinesToBlockMultibyteUtf8
{
  // Construct a large (> buffer size) stdout consisting of multibyte unicode
  // characters, once with 0 offset, and once with 1 offset (to ensure that any
  // buffer splitting won't get lucky and end up at a character boundary)

  const NSInteger lineLength = 1024*1024;

  NSString *multibyteChar = @"\U00010196"; // ROMAN DENARIUS SIGN
  NSString *longLine = [@"" stringByPaddingToLength:lineLength withString:multibyteChar startingAtIndex:0];

  NSString *fakeInput1 = [NSString stringWithFormat:@"%@\n%@\n%@", longLine, longLine, longLine];
  NSString *fakeInput2 = [@"a" stringByAppendingString:fakeInput1];

  for (NSString *fakeInput in @[fakeInput1, fakeInput2]) {
    FakeTask *fakeTask = (FakeTask *)[FakeTask fakeTaskWithExitStatus:0];
    [fakeTask pretendTaskReturnsStandardOutput:fakeInput];

    __block int lineCount = 0;
    LaunchTaskAndFeedOuputLinesToBlock(fakeTask, @"test", ^(int fd, NSString *str) {
      if ([str hasPrefix:@"a"]) {
        str = [str substringFromIndex:1];
      }
      XCTAssertTrue([str isEqualToString:longLine], @"output lines should be equal to input lines");
      lineCount++;
    });
    XCTAssertEqual(lineCount, 3, @"should have emitted 3 lines");
  }
}

- (void)testConversionToUT8OfBrokenUTF8SequenceOfBytes
{
  NSData *data = [NSData dataWithContentsOfFile:TEST_DATA @"BrokenUTF8EncodingInFile.txt"];
  NSString *string = StringFromDispatchDataWithBrokenUTF8Encoding(data.bytes, data.length);
  NSString *fixedString = [NSString stringWithContentsOfFile:TEST_DATA @"BrokenUTF8EncodingInFile-FIXED.txt" encoding:NSUTF8StringEncoding error:nil];
  XCTAssertEqualObjects(string, fixedString);

  NSString *regularString = @"qwertyuiopasdfghjk';123^&*()_<>?";
  NSData *regularStringData = [regularString dataUsingEncoding:NSUTF8StringEncoding];
  XCTAssertEqualObjects(StringFromDispatchDataWithBrokenUTF8Encoding(regularStringData.bytes, regularStringData.length), regularString);
}

@end
