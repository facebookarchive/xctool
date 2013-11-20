//
// Copyright 2013 Facebook
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

#import <SenTestingKit/SenTestingKit.h>

#import "XCToolUtil.h"
#import "Swizzler.h"
#import "TestUtil.h"

@interface XCToolUtilTests : SenTestCase
@end

@implementation XCToolUtilTests

- (void)testParseArgumentsFromArgumentString
{
  assertThat(ParseArgumentsFromArgumentString(@""), equalTo(@[]));
  assertThat(ParseArgumentsFromArgumentString(@"Arg"), equalTo(@[@"Arg"]));
  assertThat(ParseArgumentsFromArgumentString(@"Arg1 Arg2"), equalTo(@[@"Arg1", @"Arg2"]));
  assertThat(ParseArgumentsFromArgumentString(@"\"Arg1\" Arg2"), equalTo(@[@"Arg1", @"Arg2"]));
  assertThat(ParseArgumentsFromArgumentString(@"\"Arg1\"     Arg2"), equalTo(@[@"Arg1", @"Arg2"]));
  assertThat(ParseArgumentsFromArgumentString(@"Arg1 \"Arg 2\""), equalTo(@[@"Arg1", @"Arg 2"]));
  assertThat(ParseArgumentsFromArgumentString(@"Arg1 \"Arg 2\" Arg3"), equalTo(@[@"Arg1", @"Arg 2", @"Arg3"]));
  assertThat(ParseArgumentsFromArgumentString(@"Arg1 \\\"Arg 2\\\""), equalTo(@[@"Arg1", @"\"Arg", @"2\""]));
  assertThat(ParseArgumentsFromArgumentString(@"\"Arg\""), equalTo(@[@"Arg"]));
  assertThat(ParseArgumentsFromArgumentString(@"\"Arg"), equalTo(@[@"Arg"]));
  assertThat(ParseArgumentsFromArgumentString(@"Arg\""), equalTo(@[@"Arg"]));
  assertThat(ParseArgumentsFromArgumentString(@"Arg\"\""), equalTo(@[@"Arg"]));
  assertThat(ParseArgumentsFromArgumentString(@"\"Arg"), equalTo(@[@"Arg"]));
  assertThat(ParseArgumentsFromArgumentString(@"Arg1 \"Arg2"), equalTo(@[@"Arg1", @"Arg2"]));
  assertThat(ParseArgumentsFromArgumentString(@"\"\"Arg"), equalTo(@[@"Arg"]));
  assertThat(ParseArgumentsFromArgumentString(@"\\\\Arg"), equalTo(@[@"\\Arg"]));
  assertThat(ParseArgumentsFromArgumentString(@"'Arg'"), equalTo(@[@"Arg"]));
  assertThat(ParseArgumentsFromArgumentString(@"'Arg"), equalTo(@[@"Arg"]));
  assertThat(ParseArgumentsFromArgumentString(@"Arg'"), equalTo(@[@"Arg"]));
  assertThat(ParseArgumentsFromArgumentString(@"'Arg1' Arg2"), equalTo(@[@"Arg1", @"Arg2"]));
  assertThat(ParseArgumentsFromArgumentString(@"'\"Arg\"'"), equalTo(@[@"\"Arg\""]));
  assertThat(ParseArgumentsFromArgumentString(@"\"'Arg'\""), equalTo(@[@"'Arg'"]));
  assertThat(ParseArgumentsFromArgumentString(@"Arg1 \\'Arg 2\\'"), equalTo(@[@"Arg1", @"'Arg", @"2'"]));
}
@end

