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

@interface RunTestsActionTests : SenTestCase
@end

@implementation RunTestsActionTests

- (void)setUp
{
  [super setUp];
  SetTaskInstanceBlock(nil);
  ReturnFakeTasks(nil);
}

- (void)testTestSDKIsCollected
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
                      @"run-tests", @"-test-sdk", @"iphonesimulator6.0"
                      ]];
  RunTestsAction *action = options.actions[0];
  assertThat((action.testSDK), equalTo(@"iphonesimulator6.0"));
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
                      @"run-tests", @"-only", @"TestProject-LibraryTests",
                      ]];
  RunTestsAction *action = options.actions[0];
  assertThat((action.onlyList), equalTo(@[@"TestProject-LibraryTests"]));
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
   @"run-tests", @"-only", @"BOGUS_TARGET",
   ]
                                       failsWithMessage:@"run-tests: 'BOGUS_TARGET' is not a testing target in this scheme."];
}

- (void)testWithSDKsDefaultsToValueOfSDKIfNotSupplied
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
                      @"run-tests",
                      ]];
  RunTestsAction *action = options.actions[0];
  assertThat(action.testSDK, equalTo(@"iphonesimulator6.1"));
}

- (void)testOnlyAllowSimulatorSDKsForTesting
{
  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);

  // This should run w/out exception
  [TestUtil validatedOptionsFromArgumentList:@[
                      @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                      @"-scheme", @"TestProject-Library",
                      @"-sdk", @"iphonesimulator6.1",
                      @"run-tests",
                      ]];

  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);

  [TestUtil assertThatOptionsValidateWithArgumentList:@[
   @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
   @"-scheme", @"TestProject-Library",
   @"-sdk", @"iphoneos6.1",
   @"run-tests"]
                            failsWithMessage:@"run-tests: 'iphoneos6.1' is not a supported SDK for testing."];
}

- (void)testRunTestsAction
{
  XCTool *tool = [[[XCTool alloc] init] autorelease];

  tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"-configuration", @"Debug",
                     @"-sdk", @"iphonesimulator6.0",
                     @"run-tests"];

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

  // And, another to get build settings for the test target.
  NSTask *task2 = [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-showBuildSettings.txt"
                                 standardErrorPath:nil];
  NSArray *task2ExpectedArguments = @[
                                      @"-configuration", @"Debug",
                                      @"-sdk", @"iphonesimulator6.0",
                                      @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                                      @"-target", @"TestProject-LibraryTests",
                                      @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates",
                                      @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Products",
                                      @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates/PrecompiledHeaders",
                                      @"-showBuildSettings"
                                      ];

  // And, another to actually run the tests.  The tests DO fail, so it exit status should be 1.
  NSTask *task3 = [FakeTask fakeTaskWithExitStatus:1
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-test-results.txt"
                                 standardErrorPath:nil];
  NSArray *task3ExpectedArguments = @[
                                      @"-NSTreatUnknownArgumentsAsOpen", @"NO",
                                      @"-ApplePersistenceIgnoreState", @"YES",
                                      @"-SenTest", @"DisabledTests",
                                      @"-SenTestInvertScope", @"YES",
                                      @"/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Products/Debug-iphonesimulator/TestProject-LibraryTests.octest",
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
  assertThatInt(tool.exitStatus, equalToInt(1));
}

- (void)testCanRunTestsAgainstDifferentTestSDK
{
  XCTool *tool = [[[XCTool alloc] init] autorelease];

  tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"-configuration", @"Debug",
                     @"-sdk", @"iphonesimulator6.0",
                     @"run-tests", @"-test-sdk", @"iphonesimulator5.0",
                     ];

  // We'll expect to see one call to xcodebuild with -showBuildSettings - we have to fetch the OBJROOT
  // and SYMROOT variables so we can build the tests in the correct location.
  NSTask *task1 = [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil];
  NSArray *task1Arguments = @[
                              @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                              @"-scheme", @"TestProject-Library",
                              @"-configuration", @"Debug",
                              @"-sdk", @"iphonesimulator6.0",
                              @"-showBuildSettings"
                              ];

  NSArray *(^tasksThatFetchSettingsThenRun)(NSString *, NSString *) = ^(NSString *version, NSString *outputPath){
    // And, another to get build settings for the test target.
    NSTask *settingsTask = [FakeTask fakeTaskWithExitStatus:0
                                         standardOutputPath:outputPath
                                          standardErrorPath:nil];

    // And, another to actually run the tests.  The tests DO fail, so it exit status should be 1.
    NSTask *runTask = [FakeTask fakeTaskWithExitStatus:1
                                    standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-LibraryTests-test-results.txt"
                                     standardErrorPath:nil];
    return @[settingsTask, runTask];
  };

  NSArray *(^argumentsForTasksThatFetchSettingsThenRun)(NSString *, NSString *) = ^(NSString *version, NSString *outputPath){
    // And, another to get build settings for the test target.
    NSArray *settingsTaskArguments = @[
                                       @"-configuration", @"Debug",
                                       @"-sdk", [NSString stringWithFormat:@"iphonesimulator%@", version],
                                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                                       @"-target", @"TestProject-LibraryTests",
                                       @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates",
                                       @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Products",
                                       @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates/PrecompiledHeaders",
                                       @"-showBuildSettings"
                                       ];

    // And, another to actually run the tests.  The tests DO fail, so it exit status should be 1.
    NSArray *runTaskArguments = @[
                                  @"-NSTreatUnknownArgumentsAsOpen", @"NO",
                                  @"-ApplePersistenceIgnoreState", @"YES",
                                  @"-SenTest", @"DisabledTests",
                                  @"-SenTestInvertScope", @"YES",
                                  @"/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Products/Debug-iphonesimulator/TestProject-LibraryTests.octest",
                                  ];

    return @[settingsTaskArguments, runTaskArguments];
  };

  NSMutableArray *sequenceOfTasks = [NSMutableArray array];
  [sequenceOfTasks addObject:task1];
  [sequenceOfTasks addObjectsFromArray:tasksThatFetchSettingsThenRun(@"5.0", TEST_DATA @"TestProject-Library-TestProject-LibraryTests-showBuildSettings-5.0.txt")];

  NSMutableArray *sequenceOfArguments = [NSMutableArray array];
  [sequenceOfArguments addObject:task1Arguments];
  [sequenceOfArguments addObjectsFromArray:argumentsForTasksThatFetchSettingsThenRun(@"5.0", TEST_DATA @"TestProject-Library-TestProject-LibraryTests-showBuildSettings-5.0.txt")];

  __block NSUInteger sequenceOffset = 0;

  SetTaskInstanceBlock(^(void){
    return [sequenceOfTasks objectAtIndex:sequenceOffset++];
  });

  [TestUtil runWithFakeStreams:tool];

  for (int i = 0; i < sequenceOfTasks.count; i++) {
    assertThat([sequenceOfTasks[i] arguments], equalTo(sequenceOfArguments[i]));
  }

  assertThatInt(tool.exitStatus, equalToInt(1));
}

@end
