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

#import "FakeTask.h"
#import "TaskUtil.h"
#import "TestUtil.h"
#import "Version.h"
#import "XCTool.h"
#import "XCToolUtil.h"

@interface XCToolTests : SenTestCase
@end

@implementation XCToolTests

- (void)setUp
{
  [super setUp];
  SetTaskInstanceBlock(nil);
  ReturnFakeTasks(nil);
}

- (void)tearDown
{
  [super tearDown];
}

- (void)testCallingWithHelpPrintsUsage
{
  XCTool *tool = [[[XCTool alloc] init] autorelease];
  tool.arguments = @[@"-help"];

  NSDictionary *result = [TestUtil runWithFakeStreams:tool];

  assertThatInt(tool.exitStatus, equalToInt(1));
  assertThat((result[@"stderr"]), startsWith(@"usage: xctool"));
}

- (void)testCanPrintVersion
{
  XCTool *tool = [[[XCTool alloc] init] autorelease];
  tool.arguments = @[@"-version"];

  NSDictionary *result = [TestUtil runWithFakeStreams:tool];

  assertThatInt(tool.exitStatus, equalToInt(0));
  assertThat((result[@"stdout"]),
             equalTo([NSString stringWithFormat:@"%@\n", XCToolVersionString]));
}

- (void)testCallingWithNoArgsDefaultsToBuild
{
  XCTool *tool = [[[XCTool alloc] init] autorelease];
  tool.arguments = @[];

  NSDictionary *result = [TestUtil runWithFakeStreams:tool];

  assertThatInt(tool.exitStatus, equalToInt(1));
  assertThat((result[@"stderr"]), startsWith(@"ERROR:"));
}

- (void)testCallingWithShowBuildSettingsPassesThroughToXcodebuild
{
  NSArray *fakeTasks = @[[FakeTask fakeTaskWithExitStatus:0
                                       standardOutputPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"
                                        standardErrorPath:nil],
                         ];

  XCTool *tool = [[[XCTool alloc] init] autorelease];
  ReturnFakeTasks(fakeTasks);

  tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"-showBuildSettings",
                     ];

  NSDictionary *output = [TestUtil runWithFakeStreams:tool];

  assertThat(([fakeTasks[0] arguments]),
             equalTo(@[
                     @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"-showBuildSettings",
                     ]));
  assertThat(output[@"stdout"], startsWith(@"Build settings"));
}

@end
