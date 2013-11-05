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

- (void)testGetProductVersion
{
  [Swizzler whileSwizzlingSelector:@selector(dictionaryWithContentsOfFile:)
                          forClass:[NSDictionary class]
                         withBlock:
   ^(id self, SEL cmd, NSString *path) {
     return @{@"ProductVersion" : @"6.0"};
   }
                          runBlock:
   ^{
     assertThat(GetProductVersionForSDKVersion(@"6.0"), equalTo(@"6.0"));
   }];

  [Swizzler whileSwizzlingSelector:@selector(dictionaryWithContentsOfFile:)
                          forClass:[NSDictionary class]
                         withBlock:
   ^(id self, SEL cmd, NSString *path) {
     return @{@"ProductVersion" : @"7.0.3"};
   }
                          runBlock:
   ^{
     assertThat(GetProductVersionForSDKVersion(@"7.0"), equalTo(@"7.0.3"));
   }];

  // If we try to get the SDK version for an SDK that's not installed, we should
  // just get UNKNOWN.  In practice, this only happens inside of tests that are
  // written against old SDK versions (like iphonesimulator5.0, which most people
  // don't have installed.
  assertThat(GetProductVersionForSDKVersion(@"2.0"), equalTo(@"UNKNOWN"));
}

- (void)testGetSDKVersionString
{
  [Swizzler whileSwizzlingSelector:@selector(dictionaryWithContentsOfFile:)
                          forClass:[NSDictionary class]
                         withBlock:
   ^(id self, SEL cmd, NSString *path) {
     return @{@"ProductBuildVersion" : @"10A403"};
   }
                          runBlock:
   ^{
     assertThat(GetIPhoneSimulatorVersionsStringForSDKVersion(@"6.0"), equalTo(@"iPhone Simulator (external launch) , iPhone OS 6.0 (unknown/10A403)"));
   }];

  [Swizzler whileSwizzlingSelector:@selector(dictionaryWithContentsOfFile:)
                          forClass:[NSDictionary class]
                         withBlock:
   ^(id self, SEL cmd, NSString *path) {
     return @{@"ProductBuildVersion" : @"10B141"};
   }
                          runBlock:
   ^{
     assertThat(GetIPhoneSimulatorVersionsStringForSDKVersion(@"6.1"), equalTo(@"iPhone Simulator (external launch) , iPhone OS 6.1 (unknown/10B141)"));
  }];

  // If we try to get the SDK version for an SDK that's not installed, we should
  // just get UNKNOWN.  In practice, this only happens inside of tests that are
  // written against old SDK versions (like iphonesimulator5.0, which most people
  // don't have installed.
  assertThat(GetIPhoneSimulatorVersionsStringForSDKVersion(@"2.0"), equalTo(@"iPhone Simulator (external launch) , iPhone OS 2.0 (unknown/UNKNOWN)"));
}

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
  assertThat(ParseArgumentsFromArgumentString(@"'Arg1' Arg2"), equalTo(@[@"Arg1", @"Arg2"]));
  assertThat(ParseArgumentsFromArgumentString(@"'\"Arg\"'"), equalTo(@[@"\"Arg\""]));
  assertThat(ParseArgumentsFromArgumentString(@"\"'Arg'\""), equalTo(@[@"'Arg'"]));
  assertThat(ParseArgumentsFromArgumentString(@"Arg1 \\'Arg 2\\'"), equalTo(@[@"Arg1", @"'Arg", @"2'"]));
}
@end