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
#import "FakeTaskManager.h"
#import "FakeTask.h"

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

-(void)testGetAvailableSDKsAndAliases
{
  // Mock the output of the call to "/usr/bin/xcodebuild" with fake data
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
      ^(FakeTask *task) {
      if ([[task launchPath] hasSuffix:@"usr/bin/xcodebuild"] &&
          [[task arguments] isEqualToArray:@[@"-sdk", @"-version"]]) {
        NSString *fakeOutput = [NSString stringWithContentsOfFile:TEST_DATA
                                @"TestGetAvailableSDKsAndAliasesOutput.txt"
                                                         encoding:NSUTF8StringEncoding error:nil];
        [task pretendTaskReturnsStandardOutput:fakeOutput];
      }
    }
    ]];
    NSDictionary *actual = GetAvailableSDKsAndAliases();
    NSDictionary *expected = @{@"macosx10.8": @"macosx10.8",
                              @"macosx": @"macosx10.9",
                              @"macosx10.9": @"macosx10.9",
                              @"iphoneos7.0": @"iphoneos7.0",
                              @"iphoneos": @"iphoneos7.0",
                              @"iphonesimulator7.0": @"iphonesimulator7.0",
                              @"iphonesimulator": @"iphonesimulator7.0"};
    // Ensure that the two returned dictionaries are equal in terms of content
    BOOL result = [expected isEqualToDictionary:actual];
    
    assertThatBool(result, equalToBool(YES));
    
  } withDefaultLaunchHandlers:NO];
}

-(void)testGetAvailableSDKsInfo
{
  // Mock the output of the call to "/usr/bin/xcodebuild" with fake data
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
                                                              ^(FakeTask *task) {
      if ([[task launchPath] hasSuffix:@"usr/bin/xcodebuild"] &&
          [[task arguments] isEqualToArray:@[@"-sdk", @"-version"]]) {
        NSString *fakeOutput = [NSString stringWithContentsOfFile:TEST_DATA
                                @"TestGetAvailableSDKsAndAliasesOutput.txt"
                                                         encoding:NSUTF8StringEncoding error:nil];
        [task pretendTaskReturnsStandardOutput:fakeOutput];
      }
    }
                                                               ]];
    
    NSDictionary *actual = GetAvailableSDKsInfo();
    NSDictionary *expected = @{@"macosx10.8": @{@"SDK": @"macosx10.8",
                                @"SDKVersion": @"10.8",
                                @"Path": @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk",
                                @"PlatformVersion": @"1.1",
                                @"PlatformPath": @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform",
                                @"ProductBuildVersion": @"12F37",
                                @"ProductCopyright": @"1983-2013 Apple Inc.",
                                @"ProductName": @"Mac OS X",
                                @"ProductUserVisibleVersion": @"10.8.5",
                                @"ProductVersion": @"10.8.5"
                                },
                              @"macosx": @{@"SDK": @"macosx10.9",
                                @"SDKVersion": @"10.9",
                                @"Path": @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.9.sdk",
                                @"PlatformVersion": @"1.1",
                                @"PlatformPath": @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform",
                                @"ProductBuildVersion": @"13A595",
                                @"ProductCopyright": @"1983-2013 Apple Inc.",
                                @"ProductName": @"Mac OS X",
                                @"ProductUserVisibleVersion": @"10.9",
                                @"ProductVersion": @"10.9"
                                },
                              @"macosx10.9": @{@"SDK": @"macosx10.9",
                                @"SDKVersion": @"10.9",
                                @"Path": @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.9.sdk",
                                @"PlatformVersion": @"1.1",
                                @"PlatformPath": @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform",
                                @"ProductBuildVersion": @"13A595",
                                @"ProductCopyright": @"1983-2013 Apple Inc.",
                                @"ProductName": @"Mac OS X",
                                @"ProductUserVisibleVersion": @"10.9",
                                @"ProductVersion": @"10.9"
                                },
                              @"iphoneos7.0": @{@"SDK": @"iphoneos7.0",
                                @"SDKVersion": @"7.0",
                                @"Path": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS7.0.sdk",
                                @"PlatformVersion": @"7.0",
                                @"PlatformPath": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform",
                                @"ProductBuildVersion": @"11B508",
                                @"ProductCopyright": @"1983-2013 Apple Inc.",
                                @"ProductName": @"iPhone OS",
                                @"ProductVersion": @"7.0.3"
                                },
                              @"iphoneos": @{@"SDK": @"iphoneos7.0",
                                @"SDKVersion": @"7.0",
                                @"Path": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS7.0.sdk",
                                @"PlatformVersion": @"7.0",
                                @"PlatformPath": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform",
                                @"ProductBuildVersion": @"11B508",
                                @"ProductCopyright": @"1983-2013 Apple Inc.",
                                @"ProductName": @"iPhone OS",
                                @"ProductVersion": @"7.0.3"
                                },
                              @"iphonesimulator7.0": @{@"SDK": @"iphonesimulator7.0",
                                @"SDKVersion": @"7.0",
                                @"Path": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator7.0.sdk",
                                @"PlatformPath": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform",
                                @"ProductBuildVersion": @"11B508",
                                @"ProductCopyright": @"1983-2013 Apple Inc.",
                                @"ProductName": @"iPhone OS",
                                @"ProductVersion": @"7.0.3"
                                },
                              @"iphonesimulator": @{@"SDK": @"iphonesimulator7.0",
                                @"SDKVersion": @"7.0",
                                @"Path": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator7.0.sdk",
                                @"PlatformPath": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform",
                                @"ProductBuildVersion": @"11B508",
                                @"ProductCopyright": @"1983-2013 Apple Inc.",
                                @"ProductName": @"iPhone OS",
                                @"ProductVersion": @"7.0.3"
                                }};
    // Ensure that the two returned dictionaries are equal in terms of content
    BOOL result = [expected isEqualToDictionary:actual];
    
    assertThatBool(result, equalToBool(YES));
    
  } withDefaultLaunchHandlers:NO];
}

@end