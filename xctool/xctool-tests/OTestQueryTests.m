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

#import "OCUnitIOSAppTestQueryRunner.h"
#import "OCUnitIOSLogicTestQueryRunner.h"
#import "OCUnitOSXAppTestQueryRunner.h"
#import "OCUnitOSXLogicTestQueryRunner.h"
#import "SimulatorInfo.h"
#import "TestUtil.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

@interface SimulatorInfo (Helper)
+ (SimulatorInfo *)simulatorInfoWithBuildSettings:(NSDictionary *)buildSettings;
@end

@implementation SimulatorInfo (Helper)
+ (SimulatorInfo *)simulatorInfoWithBuildSettings:(NSDictionary *)buildSettings
{
  SimulatorInfo *info = [[SimulatorInfo alloc] init];
  info.buildSettings = buildSettings;
  return info;
}
@end

@interface OTestQueryTests : XCTestCase
@end

@implementation OTestQueryTests

- (void)testCanQueryClassesFromOSXBundle
{
  if (ToolchainIsXcode7OrBetter()) {
    // octest isn't supported in Xcode 7
    return;
  }

  NSString *error = nil;
  NSDictionary *buildSettings = @{
    Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"tests-osx-test-bundle"),
    Xcode_FULL_PRODUCT_NAME : @"TestProject-Library-OSXTests.octest",
    Xcode_TARGETED_DEVICE_FAMILY : @"1",
  };
  OCUnitTestQueryRunner *runner = [[OCUnitOSXLogicTestQueryRunner alloc] initWithSimulatorInfo:[SimulatorInfo simulatorInfoWithBuildSettings:buildSettings]];
  NSArray *classes = [runner runQueryWithError:&error];
  assertThat(error, is(nilValue()));
  assertThat(classes,
             equalTo(@[
                     @"TestProject_Library_OSXTests/testOutput",
                     @"TestProject_Library_OSXTests/testWillFail",
                     @"TestProject_Library_OSXTests/testWillPass",
                     ]));
}

- (void)testCanQueryClassesFromOSXBundle_AppTests
{
  NSString *error = nil;
  NSDictionary *buildSettings = @{
                                  Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"TestProject-App-OSX/Build/Products/Debug"),
                                  Xcode_FULL_PRODUCT_NAME : @"TestProject-App-OSXTests.xctest",
                                  Xcode_SDK_NAME : GetAvailableSDKsAndAliases()[@"macosx"],
                                  Xcode_TEST_HOST : AbsolutePathFromRelative(TEST_DATA @"TestProject-App-OSX/Build/Products/Debug/TestProject-App-OSX.app/Contents/MacOS/TestProject-App-OSX"),
                                  Xcode_TARGETED_DEVICE_FAMILY : @"1",
                                  };
  OCUnitTestQueryRunner *runner = [[OCUnitOSXAppTestQueryRunner alloc] initWithSimulatorInfo:[SimulatorInfo simulatorInfoWithBuildSettings:buildSettings]];
  NSArray *classes = [runner runQueryWithError:&error];
  assertThat(error, is(nilValue()));
  assertThat(classes,
             equalTo(@[@"TestProject_App_OSXTests/testCanUseSymbolsFromTestHost",
                       @"TestProject_App_OSXTests/testOutput",
                       @"TestProject_App_OSXTests/testStandardDirectories",
                       @"TestProject_App_OSXTests/testWillFail",
                       @"TestProject_App_OSXTests/testWillPass",
                       ]));
}

- (void)testCanQueryXCTestClassesFromOSXBundle
{
  if (!HasXCTestFramework()) {
    return;
  }

  NSString *error = nil;
  NSDictionary *buildSettings = @{
    Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"tests-osx-test-bundle"),
    Xcode_FULL_PRODUCT_NAME : @"TestProject-Library-XCTest-OSXTests.xctest",
    Xcode_TARGETED_DEVICE_FAMILY : @"1",
  };
  OCUnitTestQueryRunner *runner = [[OCUnitOSXLogicTestQueryRunner alloc] initWithSimulatorInfo:[SimulatorInfo simulatorInfoWithBuildSettings:buildSettings]];
  NSArray *classes = [runner runQueryWithError:&error];
  assertThat(error, is(nilValue()));
  assertThat(classes,
             equalTo(@[@"TestProject_Library_XCTest_OSXTests/testOutput",
                       @"TestProject_Library_XCTest_OSXTests/testWillFail",
                       @"TestProject_Library_XCTest_OSXTests/testWillPass"]));
}

- (void)testCanQueryCustomXCTestClasses
{
  if (!HasXCTestFramework()) {
    return;
  }

  NSString *error = nil;
  NSDictionary *buildSettings = @{
    Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"tests-osx-test-bundle"),
    Xcode_FULL_PRODUCT_NAME : @"TestProject-Library-XCTest-CustomTests.xctest",
    Xcode_TARGETED_DEVICE_FAMILY : @"1",
  };
  OCUnitTestQueryRunner *runner = [[OCUnitOSXLogicTestQueryRunner alloc] initWithSimulatorInfo:[SimulatorInfo simulatorInfoWithBuildSettings:buildSettings]];
  NSArray *classes = [runner runQueryWithError:&error];
  assertThat(error, is(nilValue()));
  assertThat(classes,
             equalTo(@[@"TestProject_Library_XCTest_CustomTests/customTest",
                       @"TestProject_Library_XCTest_CustomTests/customTestWithInteger:"]));
}

- (void)testCanQueryClassesFromIOSBundle
{
  if (ToolchainIsXcode7OrBetter()) {
    // octest isn't supported in Xcode 7
    return;
  }

  NSString *error = nil;
  NSString *latestSDK = GetAvailableSDKsAndAliases()[@"iphonesimulator"];
  NSDictionary *buildSettings = @{
    Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"tests-ios-test-bundle"),
    Xcode_FULL_PRODUCT_NAME : @"TestProject-LibraryTests.octest",
    Xcode_SDK_NAME : latestSDK,
    Xcode_TARGETED_DEVICE_FAMILY : @"1",
    Xcode_PLATFORM_NAME : @"iphonesimulator",
  };

  OCUnitTestQueryRunner *runner = [[OCUnitIOSLogicTestQueryRunner alloc] initWithSimulatorInfo:[SimulatorInfo simulatorInfoWithBuildSettings:buildSettings]];
  NSArray *classes = [runner runQueryWithError:&error];

  assertThat(error, is(nilValue()));
  assertThat(classes,
             equalTo(@[
                     @"OtherTests/testSomething",
                     @"SomeTests/testBacktraceOutputIsCaptured",
                     @"SomeTests/testOutputMerging",
                     @"SomeTests/testPrintSDK",
                     @"SomeTests/testStream",
                     @"SomeTests/testTimeout",
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
    Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"tests-ios-test-bundle"),
    Xcode_FULL_PRODUCT_NAME : @"TestProject-Library-XCTest-iOSTests.xctest",
    Xcode_SDK_NAME : latestSDK,
    Xcode_PLATFORM_NAME : @"iphonesimulator",
  };
  OCUnitTestQueryRunner *runner = [[OCUnitIOSLogicTestQueryRunner alloc] initWithSimulatorInfo:[SimulatorInfo simulatorInfoWithBuildSettings:buildSettings]];
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
  if (ToolchainIsXcode7OrBetter()) {
    // octest isn't supported in Xcode 7
    return;
  }

  NSString *error = nil;
  NSDictionary *buildSettings = @{
    Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator"),
    Xcode_FULL_PRODUCT_NAME : @"KiwiTests-OCUnit.octest",
    Xcode_SDK_NAME : GetAvailableSDKsAndAliases()[@"iphonesimulator"],
    Xcode_TARGETED_DEVICE_FAMILY : @"1",
    Xcode_PLATFORM_NAME : @"iphonesimulator",
  };
  OCUnitTestQueryRunner *runner = [[OCUnitIOSLogicTestQueryRunner alloc] initWithSimulatorInfo:[SimulatorInfo simulatorInfoWithBuildSettings:buildSettings]];
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
    Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator"),
    Xcode_FULL_PRODUCT_NAME : @"KiwiTests-XCTest.xctest",
    Xcode_SDK_NAME : GetAvailableSDKsAndAliases()[@"iphonesimulator"],
    Xcode_TARGETED_DEVICE_FAMILY : @"1",
    Xcode_PLATFORM_NAME : @"iphonesimulator",
  };
  OCUnitTestQueryRunner *runner = [[OCUnitIOSLogicTestQueryRunner alloc] initWithSimulatorInfo:[SimulatorInfo simulatorInfoWithBuildSettings:buildSettings]];
  NSArray *cases = [runner runQueryWithError:&error];
  assertThat(cases, equalTo(@[
                              @"KiwiTests_XCTest/SomeDescription_ADuplicateName",
                              @"KiwiTests_XCTest/SomeDescription_ADuplicateName_2",
                              @"KiwiTests_XCTest/SomeDescription_ItAnotherthing",
                              @"KiwiTests_XCTest/SomeDescription_ItSomething",
                              ]));
}

- (void)testCanQueryTestCasesForIOSKiwiBundle_XCTest_AppTests
{
  if (!HasXCTestFramework()) {
    return;
  }

  NSString *error = nil;
  NSDictionary *buildSettings = @{
    Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator"),
    Xcode_FULL_PRODUCT_NAME : @"KiwiTests-XCTest-AppTests.xctest",
    Xcode_SDK_NAME : GetAvailableSDKsAndAliases()[@"iphonesimulator"],
    Xcode_TEST_HOST : AbsolutePathFromRelative(TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator/KiwiTests-TestHost.app/KiwiTests-TestHost"),
    Xcode_TARGETED_DEVICE_FAMILY : @"1",
    Xcode_PLATFORM_NAME : @"iphonesimulator",
  };
  OCUnitTestQueryRunner *runner = [[OCUnitIOSAppTestQueryRunner alloc] initWithSimulatorInfo:[SimulatorInfo simulatorInfoWithBuildSettings:buildSettings]];
  NSArray *cases = [runner runQueryWithError:&error];
  assertThat(cases, equalTo(@[
                              @"KiwiTests_XCTest_AppTests/SomeDescription_ADuplicateName",
                              @"KiwiTests_XCTest_AppTests/SomeDescription_ADuplicateName_2",
                              @"KiwiTests_XCTest_AppTests/SomeDescription_ItAnotherthing",
                              @"KiwiTests_XCTest_AppTests/SomeDescription_ItSomething",
                              ]));
}

- (void)testCanQueryTestCasesForIOSKiwiBundle_OCUnit_AppTests
{
  if (ToolchainIsXcode7OrBetter()) {
    // octest isn't supported in Xcode 7
    return;
  }

  NSString *error = nil;
  NSDictionary *buildSettings = @{
    Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator"),
    Xcode_FULL_PRODUCT_NAME : @"KiwiTests-OCUnit-AppTests.octest",
    Xcode_SDK_NAME : GetAvailableSDKsAndAliases()[@"iphonesimulator"],
    Xcode_TEST_HOST : AbsolutePathFromRelative(TEST_DATA @"KiwiTests/Build/Products/Debug-iphonesimulator/KiwiTests-TestHost.app/KiwiTests-TestHost"),
    Xcode_TARGETED_DEVICE_FAMILY : @"1",
    Xcode_PLATFORM_NAME : @"iphonesimulator",
  };
  OCUnitTestQueryRunner *runner = [[OCUnitIOSAppTestQueryRunner alloc] initWithSimulatorInfo:[SimulatorInfo simulatorInfoWithBuildSettings:buildSettings]];
  NSArray *cases = [runner runQueryWithError:&error];
  assertThat(cases, equalTo(@[
                              @"KiwiTests_OCUnit_AppTests/SomeDescription_ADuplicateName",
                              @"KiwiTests_OCUnit_AppTests/SomeDescription_ADuplicateName_2",
                              @"KiwiTests_OCUnit_AppTests/SomeDescription_ItAnotherthing",
                              @"KiwiTests_OCUnit_AppTests/SomeDescription_ItSomething",
                              ]));
}

- (void)testCanQueryClassesFromIOS64BitOnlyBundle
{
  NSString *error = nil;
  NSString *latestSDK = GetAvailableSDKsAndAliases()[@"iphonesimulator"];
  NSDictionary *buildSettings = @{
    Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"tests-ios-test-bundle"),
    Xcode_FULL_PRODUCT_NAME : @"TestProject-Library-64bitTests.xctest",
    Xcode_SDK_NAME : latestSDK,
    Xcode_TARGETED_DEVICE_FAMILY : @"1",
    Xcode_PLATFORM_NAME : @"iphonesimulator",
  };

  OCUnitTestQueryRunner *runner = [[OCUnitIOSLogicTestQueryRunner alloc] initWithSimulatorInfo:[SimulatorInfo simulatorInfoWithBuildSettings:buildSettings]];
  NSArray *classes = [runner runQueryWithError:&error];

  assertThat(error, is(nilValue()));
  assertThat(classes,
             equalTo(@[
                       @"TestProjectLibrary64bitTests/testExample",
                       @"TestProjectLibrary64bitTests/testSuccess",
                       ]));
}

- (void)testCanQueryClassesFromIOS32And64BitBundle
{
  NSString *error = nil;
  NSString *latestSDK = GetAvailableSDKsAndAliases()[@"iphonesimulator"];
  NSDictionary *buildSettings = @{
    Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"tests-ios-test-bundle"),
    Xcode_FULL_PRODUCT_NAME : @"TestProject-Library-32And64bitTests.xctest",
    Xcode_SDK_NAME : latestSDK,
    Xcode_TARGETED_DEVICE_FAMILY : @"1",
    Xcode_PLATFORM_NAME : @"iphonesimulator",
  };

  OCUnitTestQueryRunner *runner = [[OCUnitIOSLogicTestQueryRunner alloc] initWithSimulatorInfo:[SimulatorInfo simulatorInfoWithBuildSettings:buildSettings]];
  NSArray *classes = [runner runQueryWithError:&error];

  assertThat(error, is(nilValue()));
  assertThat(classes,
             equalTo(@[
                       @"TestProjectLibrary64bitTests/testExample",
                       @"TestProjectLibrary64bitTests/testSuccess",
                       ]));
}

- (void)testQueryFailsWhenDYLDRejectsBundle_OSX
{
  NSString *error = nil;
  // This is going to fail, because we're trying to load an iOS test bundle using
  // the OS X version of otest.
  NSDictionary *buildSettings = @{
    Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"tests-ios-test-bundle"),
    Xcode_FULL_PRODUCT_NAME : @"TestProject-LibraryTests.octest",
  };
  OCUnitTestQueryRunner *runner = [[OCUnitOSXLogicTestQueryRunner alloc] initWithSimulatorInfo:[SimulatorInfo simulatorInfoWithBuildSettings:buildSettings]];
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
    Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"tests-osx-test-bundle"),
    Xcode_FULL_PRODUCT_NAME : @"TestProject-Library-OSXTests.octest",
    Xcode_SDK_NAME : latestSDK,
    Xcode_TARGETED_DEVICE_FAMILY : @"1",
    Xcode_PLATFORM_NAME : @"iphonesimulator",
  };
  OCUnitTestQueryRunner *runner = [[OCUnitIOSLogicTestQueryRunner alloc] initWithSimulatorInfo:[SimulatorInfo simulatorInfoWithBuildSettings:buildSettings]];
  NSArray *classes = [runner runQueryWithError:&error];

  assertThat(classes, equalTo(nil));
  assertThat(error, containsString(@"no suitable image found."));
  assertThat(error, containsString(@"not built for iOS simulator"));
}

- (void)testIOSAppTestQueryFailsWhenTestHostExecutableIsMissing
{
  NSString *error = nil;
  NSString *latestSDK = GetAvailableSDKsAndAliases()[@"iphonesimulator"];
  NSDictionary *buildSettings = @{
    Xcode_BUILT_PRODUCTS_DIR : AbsolutePathFromRelative(TEST_DATA @"tests-ios-test-bundle"),
    Xcode_FULL_PRODUCT_NAME : @"TestProject-LibraryTests.octest",
    Xcode_SDK_NAME : latestSDK,
    Xcode_TEST_HOST : @"/path/to/executable/that/does/not/exist",
    Xcode_TARGETED_DEVICE_FAMILY : @"1",
    Xcode_PLATFORM_NAME : @"iphonesimulator",
  };
  OCUnitTestQueryRunner *runner = [[OCUnitIOSAppTestQueryRunner alloc] initWithSimulatorInfo:[SimulatorInfo simulatorInfoWithBuildSettings:buildSettings]];
  NSArray *classes = [runner runQueryWithError:&error];
  assertThat(classes, equalTo(nil));
  assertThat(error, containsString(@"The test host executable is missing: '/path/to/executable/that/does/not/exist'"));
}

@end
