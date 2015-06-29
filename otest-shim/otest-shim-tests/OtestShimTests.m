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

#import "otest-shim.h"

@interface OtestShimTests : XCTestCase

@end

@implementation OtestShimTests

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

@end
