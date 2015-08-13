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

#import "XCToolUtil.h"
#import "Swizzler.h"
#import "TestUtil.h"
#import "FakeTaskManager.h"
#import "FakeTask.h"

@interface XCToolUtilTests : XCTestCase
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

- (void)testGetAvailableSDKsAndAliases
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
    assertThat(actual, equalTo(@{
      @"macosx10.10": @"macosx10.10",
      @"macosx": @"macosx10.10",
      @"macosx10.9": @"macosx10.9",
      @"iphoneos8.4": @"iphoneos8.4",
      @"iphoneos": @"iphoneos8.4",
      @"iphonesimulator8.4": @"iphonesimulator8.4",
      @"iphonesimulator": @"iphonesimulator8.4",
      @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.10.sdk": @"macosx10.10",
      @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.9.sdk": @"macosx10.9",
      @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS8.4.sdk": @"iphoneos8.4",
      @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator8.4.sdk": @"iphonesimulator8.4",
    }));
  } withDefaultLaunchHandlers:NO];
}

- (void)testGetAvailableSDKsInfo
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
    assertThat(actual, equalTo(@{
       @"iphoneos": @{
            @"SDK": @"iphoneos8.4",
            @"SDKVersion": @"8.4",
            @"Path": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS8.4.sdk",
            @"PlatformVersion": @"8.4",
            @"PlatformPath": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform",
            @"ProductBuildVersion": @"12H141",
            @"ProductCopyright": @"1983-2015 Apple Inc.",
            @"ProductName": @"iPhone OS",
            @"ProductVersion": @"8.4"
       },
       @"iphoneos8.4": @{
            @"SDK": @"iphoneos8.4",
            @"SDKVersion": @"8.4",
            @"Path": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS8.4.sdk",
            @"PlatformVersion": @"8.4",
            @"PlatformPath": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform",
            @"ProductBuildVersion": @"12H141",
            @"ProductCopyright": @"1983-2015 Apple Inc.",
            @"ProductName": @"iPhone OS",
            @"ProductVersion": @"8.4"
       },
       @"iphonesimulator": @{
            @"SDK": @"iphonesimulator8.4",
            @"SDKVersion": @"8.4",
            @"Path": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator8.4.sdk",
            @"PlatformVersion": @"8.4",
            @"PlatformPath": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform",
            @"ProductBuildVersion": @"12H141",
            @"ProductCopyright": @"1983-2015 Apple Inc.",
            @"ProductName": @"iPhone OS",
            @"ProductVersion": @"8.4"
       },
       @"iphonesimulator8.4": @{
            @"SDK": @"iphonesimulator8.4",
            @"SDKVersion": @"8.4",
            @"Path": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator8.4.sdk",
            @"PlatformVersion": @"8.4",
            @"PlatformPath": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform",
            @"ProductBuildVersion": @"12H141",
            @"ProductCopyright": @"1983-2015 Apple Inc.",
            @"ProductName": @"iPhone OS",
            @"ProductVersion": @"8.4"
       },
       @"macosx": @{
           @"SDK": @"macosx10.10",
           @"SDKVersion": @"10.10",
           @"Path": @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.10.sdk",
           @"PlatformVersion": @"1.1",
           @"PlatformPath": @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform",
           @"ProductBuildVersion": @"14D125",
           @"ProductCopyright": @"1983-2015 Apple Inc.",
           @"ProductName": @"Mac OS X",
           @"ProductUserVisibleVersion": @"10.10.3",
           @"ProductVersion": @"10.10.3"
           },
       @"macosx10.10": @{
           @"SDK": @"macosx10.10",
           @"SDKVersion": @"10.10",
           @"Path": @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.10.sdk",
           @"PlatformVersion": @"1.1",
           @"PlatformPath": @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform",
           @"ProductBuildVersion": @"14D125",
           @"ProductCopyright": @"1983-2015 Apple Inc.",
           @"ProductName": @"Mac OS X",
           @"ProductUserVisibleVersion": @"10.10.3",
           @"ProductVersion": @"10.10.3"
           },
       @"macosx10.9": @{
           @"SDK": @"macosx10.9",
           @"SDKVersion": @"10.9",
           @"Path": @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.9.sdk",
           @"PlatformVersion": @"1.1",
           @"PlatformPath": @"/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform",
           @"ProductBuildVersion": @"13F34",
           @"ProductCopyright": @"1983-2014 Apple Inc.",
           @"ProductName": @"Mac OS X",
           @"ProductUserVisibleVersion": @"10.9.5",
           @"ProductVersion": @"10.9.5"
           }}));
  } withDefaultLaunchHandlers:NO];
}

- (void)testCpuTypeForTestBundleAtPath
{
  assertThatInt(CpuTypeForTestBundleAtPath(TEST_DATA @"tests-ios-test-bundle/SenTestingKit_Assertion.octest"), equalToInt(CPU_TYPE_I386));
  assertThatInt(CpuTypeForTestBundleAtPath(TEST_DATA @"tests-ios-test-bundle/TestProject-Library-32And64bitTests.xctest"), equalToInt(CPU_TYPE_ANY));
  assertThatInt(CpuTypeForTestBundleAtPath(TEST_DATA @"tests-ios-test-bundle/TestProject-Library-64bitTests.xctest"), equalToInt(CPU_TYPE_X86_64));
}

@end
