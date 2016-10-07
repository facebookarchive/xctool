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
#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "LaunchHandlers.h"
#import "TestUtil.h"
#import "XCTool.h"

@interface ActionScriptsTests : XCTestCase
@end

@implementation ActionScriptsTests

static NSArray *GetArgs(NSString *action)
{
  return @[@"-project", TEST_DATA @"TestProject-Library-OSX/TestProject-Library-OSX.xcodeproj",
           @"-scheme", @"TestProject-Library-OSX-With-Scripts",
           @"-sdk", @"macosx",
           @"-actionScripts",
           action,
           @"-reporter", @"plain",
           ];
}

- (void)checkOutput:(NSDictionary *)outputs actions:(NSArray *)actions
{
  XCTAssertEqual([outputs[@"stderr"] length], 0, @"stderr is not empty");

  NSString *output = outputs[@"stdout"];

  for (NSString *action in actions) {
    NSRange range = [output rangeOfString:[NSString stringWithFormat:@"[Info] Running PreAction %@ Scripts...", action]];
    XCTAssertNotEqual(range.location, NSNotFound, @"Failed to match action pattern for action \"%@\" in actions \"%@\"; output: %@", action, actions, output);
    range = [output rangeOfString:[NSString stringWithFormat:@"[Info] Running PostAction %@ Scripts...", action]];
    XCTAssertNotEqual(range.location, NSNotFound, @"Failed to match action pattern for action \"%@\" in actions \"%@\"; output: %@", action, actions, output);
  }
}

- (void)runTestForTestTuple:(NSArray *)test
{
  NSString *action = test[0];
  XCTool *tool = [[XCTool alloc] init];
  tool.arguments = GetArgs(action);

  NSDictionary *output = [TestUtil runWithFakeStreams:tool];
  [self checkOutput:output actions:test[1]];
}

- (void)testActionScriptsWithBuildAction
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }
  [self runTestForTestTuple:@[@"build", @[@"build"]]];
}

- (void)testActionScriptsWithBuildTestsAction
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }
  [self runTestForTestTuple:@[@"build-tests", @[@"build"]]];
}

- (void)testActionScriptsWithRunTestsAction
{
  [self runTestForTestTuple:@[@"run-tests", @[@"test"]]];
}

- (void)testActionScriptsWithTestAction
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }
  [self runTestForTestTuple:@[@"test", @[@"build", @"test"]]];
}

- (void)testActionScriptsWithArchiveAction
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }
  [self runTestForTestTuple:@[@"archive", @[@"archive"]]];
}

- (void)testActionScriptsWithAnalyzeAction
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }
  [self runTestForTestTuple:@[@"analyze", @[@"analyze"]]];
}

@end
