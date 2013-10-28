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

#import "OCUnitIOSAppTestQueryRunner.h"
#import "OCUnitIOSLogicTestQueryRunner.h"
#import "OCUnitOSXTestQueryRunner.h"
#import "TestUtil.h"
#import "XCToolUtil.h"

@interface OTestQueryTests : SenTestCase
@end

@implementation OTestQueryTests

- (void)testCanQueryClassesFromOSXBundle
{
  NSString *error = nil;
  NSDictionary *buildSettings = @{
    kBuiltProductsDir : AbsolutePathFromRelative(TEST_DATA @"tests-osx-test-bundle"),
    kFullProductName : @"TestProject-Library-OSXTests.octest",
  };
  OCUnitOSXTestQueryRunner *runner = [[OCUnitOSXTestQueryRunner alloc] initWithBuildSettings:buildSettings
                                                                                 withCpuType:CPU_TYPE_ANY];
  NSArray *classes = [runner runQueryWithError:&error];
  assertThat(error, is(nilValue()));
  assertThat(classes,
             equalTo(@[
                     @"TestProject_Library_OSXTests/testOutput",
                     @"TestProject_Library_OSXTests/testWillFail",
                     @"TestProject_Library_OSXTests/testWillPass",
                     ]));
}

- (void)testCanQueryXCTestClassesFromOSXBundle
{
  if (!HasXCTestFramework()) {
    return;
  }

  NSString *error = nil;
  NSDictionary *buildSettings = @{
    kBuiltProductsDir : AbsolutePathFromRelative(TEST_DATA @"tests-osx-test-bundle"),
    kFullProductName : @"TestProject-Library-XCTest-OSXTests.xctest",
  };
  OCUnitOSXTestQueryRunner *runner = [[OCUnitOSXTestQueryRunner alloc] initWithBuildSettings:buildSettings
                                                                                 withCpuType:CPU_TYPE_ANY];
  NSArray *classes = [runner runQueryWithError:&error];
  assertThat(error, is(nilValue()));
  assertThat(classes,
             equalTo(@[@"TestProject_Library_XCTest_OSXTests/testOutput",
                       @"TestProject_Library_XCTest_OSXTests/testWillFail",
                       @"TestProject_Library_XCTest_OSXTests/testWillPass"]));
}

- (void)testCanQueryClassesFromIOSBundle
{
  NSString *error = nil;
  NSString *latestSDK = GetAvailableSDKsAndAliases()[@"iphonesimulator"];
  NSDictionary *buildSettings = @{
    kBuiltProductsDir : AbsolutePathFromRelative(TEST_DATA @"tests-ios-test-bundle"),
    kFullProductName : @"TestProject-LibraryTests.octest",
    kSdkName : latestSDK,
  };
  OCUnitIOSLogicTestQueryRunner *runner = [[OCUnitIOSLogicTestQueryRunner alloc] initWithBuildSettings:buildSettings
                                                                                           withCpuType:CPU_TYPE_ANY];
  NSArray *classes = [runner runQueryWithError:&error];

  assertThat(error, is(nilValue()));
  assertThat(classes,
             equalTo(@[
                     @"OtherTests/testSomething",
                     @"SomeTests/testBacktraceOutputIsCaptured",
                     @"SomeTests/testOutputMerging",
                     @"SomeTests/testPrintSDK",
                     @"SomeTests/testStream",
                     @"SomeTests/testWillFail",
                     @"SomeTests/testWillPass",
                     ]));
}

- (void)testCanQueryXCTestClassesFromIOSBundle
{
  if (!HasXCTestFramework()) {
    return;
  }

  NSString *error = nil;
  NSString *latestSDK = GetAvailableSDKsAndAliases()[@"iphonesimulator"];
  NSDictionary *buildSettings = @{
    kBuiltProductsDir : AbsolutePathFromRelative(TEST_DATA @"tests-ios-test-bundle"),
    kFullProductName : @"TestProject-Library-XCTest-iOSTests.xctest",
    kSdkName : latestSDK,
    };
  OCUnitIOSLogicTestQueryRunner *runner = [[OCUnitIOSLogicTestQueryRunner alloc] initWithBuildSettings:buildSettings
                                                                                           withCpuType:CPU_TYPE_ANY];

  NSArray *classes = [runner runQueryWithError:&error];

  assertThat(error, is(nilValue()));
  assertThat(classes,
             equalTo(@[
                       @"OtherTests/testSomething",
                       @"SomeTests/testBacktraceOutputIsCaptured",
                       @"SomeTests/testOutputMerging",
                       @"SomeTests/testPrintSDK",
                       @"SomeTests/testStream",
                       @"SomeTests/testWillFail",
                       @"SomeTests/testWillPass",
                       ]));
}

- (void)testCanQueryTestCasesForIOSKiwiBundle_OCUnit
{
  NSString *error = nil;
  NSDictionary *buildSettings = @{
                                  kBuiltProductsDir : AbsolutePathFromRelative(TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator"),
                                  kFullProductName : @"KiwiTests-OCUnit.octest",
                                  kSdkName : GetAvailableSDKsAndAliases()[@"iphonesimulator"],
                                  };
  OCUnitTestQueryRunner *runner = [[OCUnitIOSLogicTestQueryRunner alloc] initWithBuildSettings:buildSettings
                                                                                   withCpuType:CPU_TYPE_ANY];
  NSArray *cases = [runner runQueryWithError:&error];
  assertThat(cases, equalTo(@[
                              @"KiwiTests_OCUnit/SomeDescription_ADuplicateName",
                              @"KiwiTests_OCUnit/SomeDescription_ADuplicateName_2",
                              @"KiwiTests_OCUnit/SomeDescription_ItAnotherthing",
                              @"KiwiTests_OCUnit/SomeDescription_ItSomething",
                              ]));
}

- (void)testCanQueryTestCasesForIOSKiwiBundle_XCTest
{
  if (!HasXCTestFramework()) {
    return;
  }

  NSString *error = nil;
  NSDictionary *buildSettings = @{
                                  kBuiltProductsDir : AbsolutePathFromRelative(TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator"),
                                  kFullProductName : @"KiwiTests-XCTest.xctest",
                                  kSdkName : GetAvailableSDKsAndAliases()[@"iphonesimulator"],
                                  };
  OCUnitTestQueryRunner *runner = [[OCUnitIOSLogicTestQueryRunner alloc] initWithBuildSettings:buildSettings
                                                                                   withCpuType:CPU_TYPE_ANY];
  NSArray *cases = [runner runQueryWithError:&error];
  assertThat(cases, equalTo(@[
                              @"KiwiTests_XCTest/SomeDescription_ADuplicateName",
                              @"KiwiTests_XCTest/SomeDescription_ADuplicateName_2",
                              @"KiwiTests_XCTest/SomeDescription_ItAnotherthing",
                              @"KiwiTests_XCTest/SomeDescription_ItSomething",
                              ]));
}

- (void)testQueryFailsWhenDYLDRejectsBundle_OSX
{
  NSString *error = nil;
  // This is going to fail, because we're trying to load an iOS test bundle using
  // the OS X version of otest.
  NSDictionary *buildSettings = @{
    kBuiltProductsDir : AbsolutePathFromRelative(TEST_DATA @"tests-ios-test-bundle"),
    kFullProductName : @"TestProject-LibraryTests.octest",
  };
  OCUnitOSXTestQueryRunner *runner = [[OCUnitOSXTestQueryRunner alloc] initWithBuildSettings:buildSettings
                                                                                 withCpuType:CPU_TYPE_ANY];
  NSArray *classes = [runner runQueryWithError:&error];
  assertThat(classes, equalTo(nil));
  assertThat(error, containsString(@"no suitable image found."));
}

- (void)testQueryFailsWhenDYLDRejectsBundle_iOS
{
  NSString *error = nil;
  // This is going to fail, because we're trying to load an OS X test bundle
  // using the iOS version of otest.
  NSString *latestSDK = GetAvailableSDKsAndAliases()[@"iphonesimulator"];
  NSDictionary *buildSettings = @{
    kBuiltProductsDir : AbsolutePathFromRelative(TEST_DATA @"tests-osx-test-bundle"),
    kFullProductName : @"TestProject-Library-OSXTests.octest",
    kSdkName : latestSDK,
  };
  OCUnitIOSLogicTestQueryRunner *runner = [[OCUnitIOSLogicTestQueryRunner alloc] initWithBuildSettings:buildSettings
                                                                                           withCpuType:CPU_TYPE_ANY];
  NSArray *classes = [runner runQueryWithError:&error];

  assertThat(classes, equalTo(nil));
  assertThat(error, containsString(@"no suitable image found."));
}

- (void)testIOSAppTestQueryFailsWhenTestHostExecutableIsMissing
{
  NSString *error = nil;
  NSString *latestSDK = GetAvailableSDKsAndAliases()[@"iphonesimulator"];
  NSDictionary *buildSettings = @{
    kBuiltProductsDir : AbsolutePathFromRelative(TEST_DATA @"tests-ios-test-bundle"),
    kFullProductName : @"TestProject-LibraryTests.octest",
    kSdkName : latestSDK,
    kTestHost : @"/path/to/executable/that/does/not/exist",
  };
  OCUnitIOSAppTestQueryRunner *runner = [[OCUnitIOSAppTestQueryRunner alloc] initWithBuildSettings:buildSettings
                                                                                       withCpuType:CPU_TYPE_ANY];
  NSArray *classes = [runner runQueryWithError:&error];
  assertThat(classes, equalTo(nil));
  assertThat(error, containsString(@"The test host executable is missing: '/path/to/executable/that/does/not/exist'"));
}

@end
