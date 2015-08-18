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

#import "TestableExecutionInfo.h"

@interface TestableExecutionInfo ()
+ (NSString *)stringWithMacrosExpanded:(NSString *)str fromBuildSettings:(NSDictionary *)settings;
@end

@interface TestableExecutionInfoTests : XCTestCase
@end

@implementation TestableExecutionInfoTests

- (void)testMacroIsExpanded
{
  NSDictionary *buildSettings = @{
    @"PROJECT": @"TestPath/To/Project/",
    @"PROJECT_DIR": @"TestPath/To",
    @"PROJECT_": @"TestPath_",
    @"SOME_MACRO": @"MACRO_VALUE_TEST",
    @"ANOTHER": @"ANOTHER_VALUE",
  };
  NSString *expectedResult;

  /**
   * Known macro without brackets
   */
  // without prefix, with suffix
  expectedResult = [NSString stringWithFormat:@"%@/suffix1/suffix2", buildSettings[@"PROJECT"]];
  XCTAssertEqualObjects(expectedResult,
    [TestableExecutionInfo stringWithMacrosExpanded:@"$PROJECT/suffix1/suffix2"
                                  fromBuildSettings:buildSettings]);

  // with prefix and suffix
  expectedResult = [NSString stringWithFormat:@"prefix/%@/suffix", buildSettings[@"PROJECT"]];
  XCTAssertEqualObjects(expectedResult,
    [TestableExecutionInfo stringWithMacrosExpanded:@"prefix/$PROJECT/suffix"
                                  fromBuildSettings:buildSettings]);

  // only macro match
  expectedResult = [NSString stringWithFormat:@"%@", buildSettings[@"PROJECT_DIR"]];
  XCTAssertEqualObjects(expectedResult,
                [TestableExecutionInfo stringWithMacrosExpanded:@"$PROJECT_DIR"
                                              fromBuildSettings:buildSettings]);

  // without suffix, with prefix
  expectedResult = [NSString stringWithFormat:@"prefix/%@", buildSettings[@"PROJECT"]];
  XCTAssertEqualObjects(expectedResult,
    [TestableExecutionInfo stringWithMacrosExpanded:@"prefix/$PROJECT"
                                  fromBuildSettings:buildSettings]);

  /**
   * Known macro with brackets
   */
  // without prefix, with suffix
  expectedResult = [NSString stringWithFormat:@"%@/suffix1/suffix2", buildSettings[@"PROJECT"]];
  XCTAssertEqualObjects(expectedResult,
    [TestableExecutionInfo stringWithMacrosExpanded:@"$(PROJECT)/suffix1/suffix2"
                                  fromBuildSettings:buildSettings]);

  // without prefix, with suffix
  expectedResult = [NSString stringWithFormat:@"prefix/%@/suffix", buildSettings[@"PROJECT"]];
  XCTAssertEqualObjects(expectedResult,
    [TestableExecutionInfo stringWithMacrosExpanded:@"prefix/$(PROJECT)/suffix"
                                  fromBuildSettings:buildSettings]);

  // only macro match
  expectedResult = [NSString stringWithFormat:@"%@", buildSettings[@"PROJECT_DIR"]];
  XCTAssertEqualObjects(expectedResult,
                [TestableExecutionInfo stringWithMacrosExpanded:@"$(PROJECT_DIR)"
                                              fromBuildSettings:buildSettings]);

  // without suffix, with prefix
  expectedResult = [NSString stringWithFormat:@"prefix/%@", buildSettings[@"PROJECT"]];
  XCTAssertEqualObjects(expectedResult,
    [TestableExecutionInfo stringWithMacrosExpanded:@"prefix/$(PROJECT)"
                                  fromBuildSettings:buildSettings]);

  /**
   * Multiple macro replacement
   */
  expectedResult = [NSString stringWithFormat:@"%@/%@/%@", buildSettings[@"PROJECT"], buildSettings[@"PROJECT"], buildSettings[@"ANOTHER"]];
  XCTAssertEqualObjects(expectedResult,
                [TestableExecutionInfo stringWithMacrosExpanded:@"$PROJECT/$PROJECT/$ANOTHER"
                                              fromBuildSettings:buildSettings]);
  XCTAssertEqualObjects(expectedResult,
                [TestableExecutionInfo stringWithMacrosExpanded:@"$PROJECT/$(PROJECT)/$(ANOTHER)"
                                              fromBuildSettings:buildSettings]);

  expectedResult = [NSString stringWithFormat:@"%@/%@", buildSettings[@"PROJECT_DIR"], buildSettings[@"SOME_MACRO"]];
  XCTAssertEqualObjects(expectedResult,
                [TestableExecutionInfo stringWithMacrosExpanded:@"$PROJECT_DIR/$(SOME_MACRO)"
                                              fromBuildSettings:buildSettings]);
  XCTAssertEqualObjects(expectedResult,
                [TestableExecutionInfo stringWithMacrosExpanded:@"$(PROJECT_DIR)/$(SOME_MACRO)"
                                              fromBuildSettings:buildSettings]);


  expectedResult = [NSString stringWithFormat:@"prefix/%@/%@", buildSettings[@"PROJECT_DIR"], buildSettings[@"SOME_MACRO"]];
  XCTAssertEqualObjects(expectedResult,
                [TestableExecutionInfo stringWithMacrosExpanded:@"prefix/$PROJECT_DIR/$(SOME_MACRO)"
                                              fromBuildSettings:buildSettings]);

  expectedResult = [NSString stringWithFormat:@"%@/%@/suffix", buildSettings[@"PROJECT_DIR"], buildSettings[@"SOME_MACRO"]];
  XCTAssertEqualObjects(expectedResult,
                [TestableExecutionInfo stringWithMacrosExpanded:@"$(PROJECT_DIR)/$(SOME_MACRO)/suffix"
                                              fromBuildSettings:buildSettings]);

  expectedResult = [NSString stringWithFormat:@"prefix/%@/%@/suffix", buildSettings[@"PROJECT_DIR"], buildSettings[@"SOME_MACRO"]];
  XCTAssertEqualObjects(expectedResult,
                [TestableExecutionInfo stringWithMacrosExpanded:@"prefix/$(PROJECT_DIR)/$(SOME_MACRO)/suffix"
                                              fromBuildSettings:buildSettings]);

  /**
   * Unknown macro not replaced
   */
  // unknown macro
  expectedResult = @"$project";
  XCTAssertEqualObjects(expectedResult,
    [TestableExecutionInfo stringWithMacrosExpanded:@"$project"
                                  fromBuildSettings:buildSettings]);

  // unknown macro within a string
  expectedResult = @"prefix/$project/suffix";
  XCTAssertEqualObjects(expectedResult,
    [TestableExecutionInfo stringWithMacrosExpanded:@"prefix/$project/suffix"
                                  fromBuildSettings:buildSettings]);

  // unknown macro with a prefix
  expectedResult = @"prefix/$project";
  XCTAssertEqualObjects(expectedResult,
    [TestableExecutionInfo stringWithMacrosExpanded:@"prefix/$project"
                                  fromBuildSettings:buildSettings]);

  // unknown macro with a suffix
  expectedResult = @"$project/suffix";
  XCTAssertEqualObjects(expectedResult,
    [TestableExecutionInfo stringWithMacrosExpanded:@"$project/suffix"
                                  fromBuildSettings:buildSettings]);

  // macro with extra character
  expectedResult = [NSString stringWithFormat:@"$PROJECT1/suffix"];
  XCTAssertEqualObjects(expectedResult,
                [TestableExecutionInfo stringWithMacrosExpanded:@"$PROJECT1/suffix"
                                              fromBuildSettings:buildSettings]);

  // macro but case insensitive
  expectedResult = @"suffix/$PROJEcT";
  XCTAssertEqualObjects(expectedResult,
                [TestableExecutionInfo stringWithMacrosExpanded:@"suffix/$PROJEcT"
                                              fromBuildSettings:buildSettings]);

  /**
   * Unknown macro replaced with empty string
   */
  // unknown macro
  expectedResult = @"";
  XCTAssertEqualObjects(expectedResult,
    [TestableExecutionInfo stringWithMacrosExpanded:@"$(project)"
                                  fromBuildSettings:buildSettings]);

  // unknown macro within a string
  expectedResult = @"prefix//suffix";
  XCTAssertEqualObjects(expectedResult,
    [TestableExecutionInfo stringWithMacrosExpanded:@"prefix/$(project)/suffix"
                                  fromBuildSettings:buildSettings]);

  // unknown macro with a prefix
  expectedResult = @"prefix/";
  XCTAssertEqualObjects(expectedResult,
    [TestableExecutionInfo stringWithMacrosExpanded:@"prefix/$(project)"
                                  fromBuildSettings:buildSettings]);

  // unknown macro with a suffix
  expectedResult = @"/suffix";
  XCTAssertEqualObjects(expectedResult,
    [TestableExecutionInfo stringWithMacrosExpanded:@"$(project)/suffix"
                                  fromBuildSettings:buildSettings]);

  // macro with extra character
  expectedResult = [NSString stringWithFormat:@"/suffix"];
  XCTAssertEqualObjects(expectedResult,
                [TestableExecutionInfo stringWithMacrosExpanded:@"$(PROJECT1)/suffix"
                                              fromBuildSettings:buildSettings]);

  // macro but case insensitive
  expectedResult = @"suffix/";
  XCTAssertEqualObjects(expectedResult,
                [TestableExecutionInfo stringWithMacrosExpanded:@"suffix/$(PROJEcT)"
                                              fromBuildSettings:buildSettings]);

  /**
   * Match failures
   */
  for (NSString *string in @[
    @"$(project",
    @"$project)",
    @"(project)",
    @"prefix/$project)/suffix",
    @"prefix/$(project",
    @"(project)/suffix",
    @"$((PROJECT1)/suffix",
    @"suffix/$((PROJEcT))",
  ]) {
    expectedResult = string;
    XCTAssertEqualObjects(expectedResult,
      [TestableExecutionInfo stringWithMacrosExpanded:expectedResult
                                    fromBuildSettings:buildSettings]);
  }
}

@end
