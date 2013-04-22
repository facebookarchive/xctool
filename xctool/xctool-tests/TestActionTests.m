
#import <SenTestingKit/SenTestingKit.h>

#import "Action.h"
#import "FakeTask.h"
#import "Options.h"
#import "TestAction.h"
#import "TestActionInternal.h"
#import "TaskUtil.h"
#import "TestUtil.h"
#import "XCToolUtil.h"
#import "XcodeSubjectInfo.h"

@interface TestActionTests : SenTestCase
@end

@implementation TestActionTests

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
                      @"test", @"-only", @"TestProject-LibraryTests",
                      ]];
  TestAction *action = options.actions[0];
  assertThat(([action onlyList]), equalTo(@[@"TestProject-LibraryTests"]));
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
   @"test", @"-only", @"BOGUS_TARGET",
   ]
                                       failsWithMessage:@"build-tests: 'BOGUS_TARGET' is not a testing target in this scheme."];
}

@end
