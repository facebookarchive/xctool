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

#import "Action.h"
#import "BuildTestsAction.h"
#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "LaunchHandlers.h"
#import "Options+Testing.h"
#import "Options.h"
#import "RunTestsAction.h"
#import "TaskUtil.h"
#import "TestAction.h"
#import "TestActionInternal.h"
#import "XCToolUtil.h"
#import "XcodeSubjectInfo.h"

@interface TestActionTests : XCTestCase
@end

@implementation TestActionTests

- (void)testOnlyListIsCollected
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }
  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator6.1",
                       @"test", @"-only", @"TestProject-LibraryTests",
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  TestAction *action = options.actions[0];
  assertThat(([action onlyList]), equalTo(@[@"TestProject-LibraryTests"]));
}

- (void)testOmitListIsCollected
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }
  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator6.1",
                       @"test", @"-omit", @"TestProject-LibraryTests",
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  TestAction *action = options.actions[0];
  assertThat(([action omitList]), equalTo(@[@"TestProject-LibraryTests"]));
}

- (void)testOnlyListRequiresValidTarget
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }
  [[Options optionsFrom:@[
    @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
    @"-scheme", @"TestProject-Library",
    @"-sdk", @"iphonesimulator6.1",
    @"test", @"-only", @"BOGUS_TARGET",
    ]]
   assertOptionsFailToValidateWithError:
   @"build-tests: 'BOGUS_TARGET' is not a testing target in this scheme."
   withBuildSettingsFromFile:
   TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
   ];
}

- (void)testSkipDependenciesIsCollected
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }
  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator6.1",
                       @"test", @"-only", @"TestProject-LibraryTests",
                       @"-skip-deps"
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  TestAction *action = options.actions[0];
  assertThatBool(action.skipDependencies, isTrue());
}

- (void)testOnlyParsing
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }
  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"test", @"-only", @"TestProject-LibraryTests:ClassName/methodName"
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  assertThat([options.actions[0] buildTestsAction].onlyList, equalTo(@[@"TestProject-LibraryTests"]));
  assertThat([options.actions[0] runTestsAction].onlyList, equalTo(@[@"TestProject-LibraryTests:ClassName/methodName"]));
}

- (void)testOmitParsing
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }
  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"test", @"-omit", @"TestProject-LibraryTests:ClassName/methodName"
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  assertThat([options.actions[0] buildTestsAction].omitList, equalTo(@[@"TestProject-LibraryTests"]));
  assertThat([options.actions[0] runTestsAction].omitList, equalTo(@[@"TestProject-LibraryTests:ClassName/methodName"]));
}

@end
