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
#import "BuildTestsAction.h"
#import "FakeTask.h"
#import "Options.h"
#import "TaskUtil.h"
#import "TestUtil.h"
#import "XCToolUtil.h"
#import "xcodeSubjectInfo.h"

@interface BuildTestsActionTests : SenTestCase
@end

@implementation BuildTestsActionTests

- (void)setUp
{
  [super setUp];
  SetTaskInstanceBlock(nil);
  ReturnFakeTasks(nil);
}

- (void)testOnlyListIsCollected
{
  // The subject being the workspace/scheme or project/target we're testing.
  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);

  Options *options = [TestUtil validatedOptionsFromArgumentList:@[
                      @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                      @"-scheme", @"TestProject-Library",
                      @"-sdk", @"iphonesimulator6.1",
                      @"build-tests", @"-only", @"TestProject-LibraryTests",
                      ]];
  BuildTestsAction *action = options.actions[0];
  assertThat((action.onlyList), equalTo(@[@"TestProject-LibraryTests"]));
}


- (void)testSkipDependenciesIsCollected
{
  // The subject being the workspace/scheme or project/target we're testing.
  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);

  Options *options = [TestUtil validatedOptionsFromArgumentList:@[
                      @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                      @"-scheme", @"TestProject-Library",
                      @"-sdk", @"iphonesimulator6.1",
                      @"build-tests", @"-only", @"TestProject-LibraryTests",
                      @"-skip-deps"
                      ]];
  BuildTestsAction *action = options.actions[0];
  assertThatBool(action.skipDependencies, equalToBool(YES));
}

- (void)testOnlyListRequiresValidTarget
{
  // The subject being the workspace/scheme or project/target we're testing.
  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);

  [TestUtil assertThatOptionsValidateWithArgumentList:@[
   @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
   @"-scheme", @"TestProject-Library",
   @"-sdk", @"iphonesimulator6.1",
   @"build-tests", @"-only", @"BOGUS_TARGET",
   ]
                                       failsWithMessage:@"build-tests: 'BOGUS_TARGET' is not a testing target in this scheme."];
}

- (void)testBuildTestsAction
{
  XCTool *tool = [[[XCTool alloc] init] autorelease];

  tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"-configuration", @"Debug",
                     @"-sdk", @"iphonesimulator6.0",
                     @"build-tests"];

  // We'll expect to see one call to xcodebuild with -showBuildSettings - we have to fetch the OBJROOT
  // and SYMROOT variables so we can build the tests in the correct location.
  NSTask *task1 = [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil];
  NSArray *task1ExpectedArguments = @[
                                      @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                                      @"-scheme", @"TestProject-Library",
                                      @"-configuration", @"Debug",
                                      @"-sdk", @"iphonesimulator6.0",
                                      @"-showBuildSettings"
                                      ];


  // We'll expect to see another xcodebuild call to build the test target.
  NSTask *task2 = [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-build.txt"
                                 standardErrorPath:nil];
  NSArray *task2ExpectedArguments = @[
                                      @"-configuration", @"Debug",
                                      @"-sdk", @"iphonesimulator6.0",
                                      @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                                      @"-target", @"TestProject-Library",
                                      @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates",
                                      @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Products",
                                      @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates/PrecompiledHeaders",
                                      @"build",
                                      ];

  // We'll expect to see another xcodebuild call to build the test target.
  NSTask *task3 = [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-build.txt"
                                 standardErrorPath:nil];
  NSArray *task3ExpectedArguments = @[
                                      @"-configuration", @"Debug",
                                      @"-sdk", @"iphonesimulator6.0",
                                      @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                                      @"-target", @"TestProject-LibraryTests",
                                      @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates",
                                      @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Products",
                                      @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates/PrecompiledHeaders",
                                      @"build",
                                      ];

  NSArray *sequenceOfTasks = @[task1, task2, task3];
  __block NSUInteger sequenceOffset = 0;

  SetTaskInstanceBlock(^(void){
    return [sequenceOfTasks objectAtIndex:sequenceOffset++];
  });

  [TestUtil runWithFakeStreams:tool];

  assertThat(task1.arguments, equalTo(task1ExpectedArguments));
  assertThat(task2.arguments, equalTo(task2ExpectedArguments));
  assertThat(task3.arguments, equalTo(task3ExpectedArguments));
  assertThatInt(tool.exitStatus, equalToInt(0));
}

- (void)testBuildTestsActionWillBuildEverythingMarkedAsBuildForTest
{
  // In TestWorkspace-Library, we have a target TestProject-LibraryTest2 that depends on
  // TestProject-OtherLib, but it isn't marked as an explicit dependency.  The only way that
  // dependency gets built is that it's added to the scheme as build-for-test above
  // TestProject-LibraryTest2.  This a lame way to setup dependencies (they should be explicit),
  // but we're seeing this in the wild and should support it.
  XCTool *tool = [[[XCTool alloc] init] autorelease];

  tool.arguments = @[@"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                     @"-scheme", @"TestProject-Library",
                     @"-configuration", @"Debug",
                     @"-sdk", @"iphonesimulator6.0",
                     @"build-tests"];

  // We'll expect to see one call to xcodebuild with -showBuildSettings - we have to fetch the OBJROOT
  // and SYMROOT variables so we can build the tests in the correct location.
  NSTask *task1 = [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil];
  NSArray *task1ExpectedArguments = @[
                                      @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                                      @"-scheme", @"TestProject-Library",
                                      @"-configuration", @"Debug",
                                      @"-sdk", @"iphonesimulator6.0",
                                      @"-showBuildSettings"
                                      ];

  // We'll expect to see another xcodebuild call to build the TestProject-LibraryTests
  NSTask *task2 = [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestWorkspace-Library-TestProject-LibraryTests-build.txt"
                                 standardErrorPath:nil];
  NSArray *task2ExpectedArguments = @[
                                      @"-configuration", @"Debug",
                                      @"-sdk", @"iphonesimulator6.0",
                                      @"-project", TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj",
                                      @"-target", @"TestProject-Library",
                                      @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates",
                                      @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Products",
                                      @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates/PrecompiledHeaders",
                                      @"build",
                                      ];

  NSTask *task3 = [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestWorkspace-Library-TestProject-LibraryTests-build.txt"
                                 standardErrorPath:nil];
  NSArray *task3ExpectedArguments = @[
                                      @"-configuration", @"Debug",
                                      @"-sdk", @"iphonesimulator6.0",
                                      @"-project", TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj",
                                      @"-target", @"TestProject-OtherLib",
                                      @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates",
                                      @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Products",
                                      @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates/PrecompiledHeaders",
                                      @"build",
                                      ];

  // We'll expect to see another xcodebuild call to build the TestProject-LibraryTests2
  NSTask *task4 = [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestWorkspace-Library-TestProject-LibraryTests-build.txt"
                                 standardErrorPath:nil];
  NSArray *task4ExpectedArguments = @[
                                      @"-configuration", @"Debug",
                                      @"-sdk", @"iphonesimulator6.0",
                                      @"-project", TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj",
                                      @"-target", @"TestProject-LibraryTests",
                                      @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates",
                                      @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Products",
                                      @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates/PrecompiledHeaders",
                                      @"build",
                                      ];

  // We'll expect to see another xcodebuild call to build the TestProject-LibraryTests2
  NSTask *task5 = [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestWorkspace-Library-TestProject-LibraryTests-build.txt"
                                 standardErrorPath:nil];
  NSArray *task5ExpectedArguments = @[
                                      @"-configuration", @"Debug",
                                      @"-sdk", @"iphonesimulator6.0",
                                      @"-project", TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj",
                                      @"-target", @"TestProject-LibraryTests2",
                                      @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates",
                                      @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Products",
                                      @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates/PrecompiledHeaders",
                                      @"build",
                                      ];

  NSArray *sequenceOfTasks = @[task1, task2, task3, task4, task5];
  __block NSUInteger sequenceOffset = 0;

  SetTaskInstanceBlock(^(void){
    return [sequenceOfTasks objectAtIndex:sequenceOffset++];
  });

  [TestUtil runWithFakeStreams:tool];

  assertThat(task1.arguments, equalTo(task1ExpectedArguments));
  assertThat(task2.arguments, equalTo(task2ExpectedArguments));
  assertThat(task3.arguments, equalTo(task3ExpectedArguments));
  assertThat(task4.arguments, equalTo(task4ExpectedArguments));
  assertThat(task5.arguments, equalTo(task5ExpectedArguments));
  assertThatInt(tool.exitStatus, equalToInt(0));
}

- (void)testBuildTestsCanBuildASingleTarget
{
  // In TestWorkspace-Library, we have a target TestProject-LibraryTest2 that depends on
  // TestProject-OtherLib, but it isn't marked as an explicit dependency.  The only way that
  // dependency gets built is that it's added to the scheme as build-for-test above
  // TestProject-LibraryTest2.  This a lame way to setup dependencies (they should be explicit),
  // but we're seeing this in the wild and should support it.
  XCTool *tool = [[[XCTool alloc] init] autorelease];

  tool.arguments = @[@"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                     @"-scheme", @"TestProject-Library",
                     @"-configuration", @"Debug",
                     @"-sdk", @"iphonesimulator6.0",
                     @"build-tests", @"-only", @"TestProject-LibraryTests"];

  // We'll expect to see one call to xcodebuild with -showBuildSettings - we have to fetch the OBJROOT
  // and SYMROOT variables so we can build the tests in the correct location.
  NSTask *task1 = [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil];
  NSArray *task1ExpectedArguments = @[
                                      @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                                      @"-scheme", @"TestProject-Library",
                                      @"-configuration", @"Debug",
                                      @"-sdk", @"iphonesimulator6.0",
                                      @"-showBuildSettings"
                                      ];

  // We'll expect to see another xcodebuild call to build the TestProject-Library
  NSTask *task2 = [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestWorkspace-Library-TestProject-LibraryTests-build.txt"
                                 standardErrorPath:nil];
  NSArray *task2ExpectedArguments = @[
                                      @"-configuration", @"Debug",
                                      @"-sdk", @"iphonesimulator6.0",
                                      @"-project", TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj",
                                      @"-target", @"TestProject-Library",
                                      @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates",
                                      @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Products",
                                      @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates/PrecompiledHeaders",
                                      @"build",
                                      ];

  // We'll expect to see another xcodebuild call to build the TestProject-OtherLibrary
  NSTask *task3 = [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestWorkspace-Library-TestProject-LibraryTests-build.txt"
                                 standardErrorPath:nil];
  NSArray *task3ExpectedArguments = @[
                                      @"-configuration", @"Debug",
                                      @"-sdk", @"iphonesimulator6.0",
                                      @"-project", TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj",
                                      @"-target", @"TestProject-OtherLib",
                                      @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates",
                                      @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Products",
                                      @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates/PrecompiledHeaders",
                                      @"build",
                                      ];

  // We'll expect to see another xcodebuild call to build the TestProject-LibraryTests
  NSTask *task4 = [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestWorkspace-Library-TestProject-LibraryTests-build.txt"
                                 standardErrorPath:nil];
  NSArray *task4ExpectedArguments = @[
                                      @"-configuration", @"Debug",
                                      @"-sdk", @"iphonesimulator6.0",
                                      @"-project", TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj",
                                      @"-target", @"TestProject-LibraryTests",
                                      @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates",
                                      @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Products",
                                      @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates/PrecompiledHeaders",
                                      @"build",
                                      ];


  NSArray *sequenceOfTasks = @[task1, task2, task3, task4];
  __block NSUInteger sequenceOffset = 0;

  SetTaskInstanceBlock(^(void){
    return [sequenceOfTasks objectAtIndex:sequenceOffset++];
  });

  [TestUtil runWithFakeStreams:tool];

  assertThat(task1.arguments, equalTo(task1ExpectedArguments));
  assertThat(task2.arguments, equalTo(task2ExpectedArguments));
  assertThat(task3.arguments, equalTo(task3ExpectedArguments));
  assertThat(task4.arguments, equalTo(task4ExpectedArguments));
  assertThatInt(tool.exitStatus, equalToInt(0));
}


- (void)testSkipDependencies
{
  XCTool *tool = [[[XCTool alloc] init] autorelease];

  tool.arguments = @[@"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                     @"-scheme", @"TestProject-Library",
                     @"-configuration", @"Debug",
                     @"-sdk", @"iphonesimulator6.0",
                     @"build-tests",
                     @"-only", @"TestProject-LibraryTests",
                     @"-skip-deps"];

  // We'll expect to see one call to xcodebuild with -showBuildSettings - we have to fetch the OBJROOT
  // and SYMROOT variables so we can build the tests in the correct location.
  NSTask *task1 = [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil];
  NSArray *task1ExpectedArguments = @[
                                      @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                                      @"-scheme", @"TestProject-Library",
                                      @"-configuration", @"Debug",
                                      @"-sdk", @"iphonesimulator6.0",
                                      @"-showBuildSettings"
                                      ];

  // We'll expect to see another xcodebuild call to build the TestProject-LibraryTests
  NSTask *task2 = [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestWorkspace-Library-TestProject-LibraryTests-build.txt"
                                 standardErrorPath:nil];
  NSArray *task2ExpectedArguments = @[
                                      @"-configuration", @"Debug",
                                      @"-sdk", @"iphonesimulator6.0",
                                      @"-project", TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj",
                                      @"-target", @"TestProject-LibraryTests",
                                      @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates",
                                      @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Products",
                                      @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-gjpyghvhqizojqckzrwwumrsqgoo/Build/Intermediates/PrecompiledHeaders",
                                      @"build",
                                      ];


  NSArray *sequenceOfTasks = @[task1, task2];
  __block NSUInteger sequenceOffset = 0;

  SetTaskInstanceBlock(^(void){
    return [sequenceOfTasks objectAtIndex:sequenceOffset++];
  });

  [TestUtil runWithFakeStreams:tool];

  assertThat(task1.arguments, equalTo(task1ExpectedArguments));
  assertThat(task2.arguments, equalTo(task2ExpectedArguments));
  assertThatInt(tool.exitStatus, equalToInt(0));
}

@end
