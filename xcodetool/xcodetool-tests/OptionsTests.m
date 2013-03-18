
#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>
#import "Options.h"
#import "Functions.h"
#import "TextReporter.h"
#import "XcodeSubjectInfo.h"
#import "Fakes.h"
#import "ImplicitAction.h"
#import "BuildAction.h"
#import <objc/runtime.h>

@interface OptionsTests : SenTestCase
@end

@implementation OptionsTests

- (void)setUp
{
  [super setUp];
  SetTaskInstanceBlock(nil);
  ReturnFakeTasks(nil);
}

- (Options *)optionsFromArgumentList:(NSArray *)argumentList
{
  Options *options = [[[Options alloc] init] autorelease];
  NSString *errorMessage = nil;
  BOOL parsed = [options parseOptionsFromArgumentList:argumentList errorMessage:&errorMessage];
  assertThatBool(parsed, equalToBool(YES));
  
  return options;
}

- (Options *)validatedOptionsFromArgumentList:(NSArray *)argumentList
{
  Options *options = [self optionsFromArgumentList:argumentList];
  NSString *errorMessage = nil;
  BOOL valid = [options validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease]];
  assertThatBool(valid, equalToBool(YES));
  
  return options;
}

- (void)assertThatParseArgumentList:(NSArray *)argumentList failsWithMessage:(NSString *)message
{
  Options *options = [[[Options alloc] init] autorelease];
  NSString *errorMessage = nil;
  BOOL parsed = [options parseOptionsFromArgumentList:argumentList errorMessage:&errorMessage];
  assertThatBool(parsed, equalToBool(NO));
  assertThat(errorMessage, equalTo(message));
}

- (void)assertThatValidationWithArgumentList:(NSArray *)argumentList failsWithMessage:(NSString *)message
{
  Options *options = [self optionsFromArgumentList:argumentList];
  NSString *errorMessage = nil;
  BOOL valid = [options validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease]];
  assertThatBool(valid, equalToBool(NO));
  assertThat(errorMessage, equalTo(message));
}

- (void)assertThatValidationPassesWithArgumentList:(NSArray *)argumentList
{
  Options *options = [self optionsFromArgumentList:argumentList];
  NSString *errorMessage = nil;
  BOOL valid = [options validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease]];
  assertThatBool(valid, equalToBool(YES));
}

- (void)testHelpOptionSetsPrintUsage
{
  assertThatBool([self optionsFromArgumentList:@[@"-help"]].implicitAction.showHelp, equalToBool(YES));
}

- (void)testShortHelpOptionSetsPrintUsage
{
  assertThatBool([self optionsFromArgumentList:@[@"-h"]].implicitAction.showHelp, equalToBool(YES));
}


- (void)testActionsAreRecorded
{
  NSArray *(^classNamesFromArray)(NSArray *) = ^(NSArray *arr){
    NSMutableArray *result = [NSMutableArray array];
    for (id item in arr) {
      [result addObject:[NSString stringWithUTF8String:class_getName([item class])]];
    }
    return result;
  };

  assertThat(classNamesFromArray([self optionsFromArgumentList:@[
                                  @"clean",
                                  @"build",
                                  @"build-tests",
                                  @"run-tests",
                                  ]].actions),
             equalTo(@[
                     @"CleanAction",
                     @"BuildAction",
                     @"BuildTestsAction",
                     @"RunTestsAction",
                     ]));
}

- (void)testDefaultActionIsBuildIfNotSpecified
{
  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);

  Options *options = [self validatedOptionsFromArgumentList:@[
                      @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                      @"-scheme", @"TestProject-Library",
                      ]];
  
  assertThatInteger(options.actions.count, equalToInteger(1));
  Action *action = options.actions[0];
  NSString *actionClassName = [NSString stringWithUTF8String:class_getName([action class])];
  assertThat(actionClassName, equalTo(@"BuildAction"));
}
//
//- (void)testBuildTest_RunTest_BuildAndRunTest_allRequireValidTestTarget
//{
//  void (^testPassAndFail)(NSArray *, NSArray *) = ^(NSArray *shouldPass, NSArray *shouldFail){
//    NSArray *baseArgs = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
//                          @"-scheme", @"TestProject-Library",
//                          @"-sdk", @"iphonesimulator6.1",
//                          ];
//    
//    ReturnFakeTasks(@[
//                    [FakeTask fakeTaskWithExitStatus:0
//                                  standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
//                                   standardErrorPath:nil]
//                    ]);
//    [self assertThatValidationPassesWithArgumentList:[baseArgs arrayByAddingObjectsFromArray:shouldPass]];
//    
//    ReturnFakeTasks(@[
//                    [FakeTask fakeTaskWithExitStatus:0
//                                  standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
//                                   standardErrorPath:nil]
//                    ]);
//    [self assertThatValidationWithArgumentList:[baseArgs arrayByAddingObjectsFromArray:shouldFail]
//                              failsWithMessage:[NSString stringWithFormat:@"%@: '%@' is not a valid testing target.",
//                                                shouldFail[0], shouldFail[1]]];
//
//  };
//  
//  testPassAndFail(@[@"build-test", @"TestProject-LibraryTests"],
//                  @[@"build-test", @"TestProject-LibraryTestsBOGUS"]);
//  testPassAndFail(@[@"run-test", @"TestProject-LibraryTests", @"All"],
//                  @[@"run-test", @"TestProject-LibraryTestsBOGUS", @"All"]);
//  testPassAndFail(@[@"build-and-run-test", @"TestProject-LibraryTests", @"All"],
//                  @[@"build-and-run-test", @"TestProject-LibraryTestsBOGUS", @"All"]);  
//}
//
//

@end
