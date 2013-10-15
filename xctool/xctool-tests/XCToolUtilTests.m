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
     assertThat(GetSDKVersionString(@"6.0"), equalTo(@"iPhone Simulator (external launch) , iPhone OS 6.0 (unknown/10A403)"));
   }];

  [Swizzler whileSwizzlingSelector:@selector(dictionaryWithContentsOfFile:)
                          forClass:[NSDictionary class]
                         withBlock:
   ^(id self, SEL cmd, NSString *path) {
     return @{@"ProductBuildVersion" : @"10B141"};
   }
                          runBlock:
   ^{
     assertThat(GetSDKVersionString(@"6.1"), equalTo(@"iPhone Simulator (external launch) , iPhone OS 6.1 (unknown/10B141)"));
  }];

  // If we try to get the SDK version for an SDK that's not installed, we should
  // just get UNKNOWN.  In practice, this only happens inside of tests that are
  // written against old SDK versions (like iphonesimulator5.0, which most people
  // don't have installed.
  assertThat(GetSDKVersionString(@"2.0"), equalTo(@"iPhone Simulator (external launch) , iPhone OS 2.0 (unknown/UNKNOWN)"));
}
  
@end