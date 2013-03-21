
#import <SenTestingKit/SenTestingKit.h>
#import "Action.h"
#import "xcodeSubjectInfo.h"
#import "RunTestsAction.h"
#import "ImplicitAction.h"
#import "Fakes.h"
#import "Functions.h"
#import "TestUtil.h"

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
  NSArray *fakeTasks = @[[TestUtil fakeTaskWithExitStatus:0
                                           standardOutput:[NSString stringWithContentsOfFile:TEST_DATA @"TestProject-Library-showBuildSettings.txt" encoding:NSUTF8StringEncoding error:nil]
                                            standardError:@""],
                         [[[FakeTask alloc] init] autorelease],
                         [[[FakeTask alloc] init] autorelease],
                         ];
  
  XcodeTool *tool = [[[XcodeTool alloc] init] autorelease];
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
                     @"clean",
                     ]));
}

@end
