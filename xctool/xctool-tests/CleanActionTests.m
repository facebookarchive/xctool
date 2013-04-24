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

#import "Action.h"
#import "FakeTask.h"
#import "Options.h"
#import "RunTestsAction.h"
#import "TaskUtil.h"
#import "TestUtil.h"
#import "XCToolUtil.h"
#import "xcodeSubjectInfo.h"

@interface CleanActionTests : SenTestCase
@end

@implementation CleanActionTests

- (void)setUp
{
  [super setUp];
  SetTaskInstanceBlock(nil);
  ReturnFakeTasks(nil);
}

- (void)testCleanActionTriggersCleanForProjectAndSchemeAndTests
{
  NSArray *fakeTasks = @[[FakeTask fakeTaskWithExitStatus:0
                                       standardOutputPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"
                                        standardErrorPath:nil],
                         [[[FakeTask alloc] init] autorelease],
                         [[[FakeTask alloc] init] autorelease],
                         ];

  XCTool *tool = [[[XCTool alloc] init] autorelease];
  ReturnFakeTasks(fakeTasks);

  tool.arguments = @[
                     @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"clean",
                     ];

  [TestUtil runWithFakeStreams:tool];

  assertThat([fakeTasks[1] arguments],
             equalTo(@[
                     @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"-configuration", @"Debug",
                     @"-sdk", @"iphonesimulator6.0",
                     @"clean",
                     ]));
  assertThat([fakeTasks[2] arguments],
             equalTo(@[
                     @"-configuration", @"Debug",
                     @"-sdk", @"iphonesimulator6.0",
                     @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-target", @"TestProject-LibraryTests",
                     @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates",
                     @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Products",
                     @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates/PrecompiledHeaders",
                     @"clean",
                     ]));
}

@end
