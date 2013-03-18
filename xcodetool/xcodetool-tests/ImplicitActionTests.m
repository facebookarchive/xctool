
#import <SenTestingKit/SenTestingKit.h>
#import "Action.h"
#import "ImplicitAction.h"
#import "TextReporter.h"
#import "XcodeSubjectInfo.h"
#import "Functions.h"
#import "Fakes.h"

@interface ImplicitActionTests : SenTestCase
@end

@implementation ImplicitActionTests

- (ImplicitAction *)actionWithArguments:(NSArray *)arguments
{
  ImplicitAction *action = [[ImplicitAction alloc] init];
  NSString *errorMessage = nil;
  NSUInteger consumed = [action consumeArguments:[NSMutableArray arrayWithArray:arguments] errorMessage:&errorMessage];
  assertThat(errorMessage, equalTo(nil));
  assertThatInteger(consumed, equalToInteger(arguments.count));
  return action;
}

- (ImplicitAction *)validatedActionWithArguments:(NSArray *)arguments
{
  ImplicitAction *action = [self actionWithArguments:arguments];
  NSString *errorMessage = nil;
  BOOL valid = [action validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease] implicitAction:nil];
  assertThatBool(valid, equalToBool(YES));
  return action;
}

- (void)assertThatValidationWithArgumentList:(NSArray *)argumentList
                            failsWithMessage:(NSString *)message
{
  Action *action = [self actionWithArguments:argumentList];
  NSString *errorMessage = nil;
  BOOL valid = [action validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease] implicitAction:nil];
  assertThatBool(valid, equalToBool(NO));
  assertThat(errorMessage, equalTo(message));
}

- (void)assertThatValidationPassesWithArgumentList:(NSArray *)argumentList
{
  Action *action = [self actionWithArguments:argumentList];
  NSString *errorMessage = nil;
  BOOL valid = [action validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease] implicitAction:nil];
  assertThatBool(valid, equalToBool(YES));
}

- (void)testHelpOptionSetsFlag
{
  assertThatBool([(ImplicitAction *)[self actionWithArguments:@[@"-h"]] showHelp], equalToBool(YES));
  assertThatBool([(ImplicitAction *)[self actionWithArguments:@[@"-help"]] showHelp], equalToBool(YES));
}

- (void)testOptionsPassThrough
{
  assertThat(([[self actionWithArguments:@[@"-configuration", @"SomeConfig"]] configuration]), equalTo(@"SomeConfig"));
  assertThat(([[self actionWithArguments:@[@"-arch", @"SomeArch"]] arch]), equalTo(@"SomeArch"));
  assertThat(([[self actionWithArguments:@[@"-sdk", @"SomeSDK"]] sdk]), equalTo(@"SomeSDK"));
  assertThat(([[self actionWithArguments:@[@"-workspace", @"SomeWorkspace"]] workspace]), equalTo(@"SomeWorkspace"));
  assertThat(([[self actionWithArguments:@[@"-project", @"SomeProject"]] project]), equalTo(@"SomeProject"));
  assertThat(([[self actionWithArguments:@[@"-toolchain", @"SomeToolChain"]] toolchain]), equalTo(@"SomeToolChain"));
  assertThat(([[self actionWithArguments:@[@"-xcconfig", @"something.xcconfig"]] xcconfig]), equalTo(@"something.xcconfig"));
  assertThat(([[self actionWithArguments:@[@"-jobs", @"10"]] jobs]), equalTo(@"10"));
}

- (void)testReporterOptionsAreCollected
{
  NSArray *reporters = [[self actionWithArguments:@[@"-reporter", @"pretty", @"-reporter", @"plain:out.txt"]] reporters];
  assertThatInteger(reporters.count, equalToInteger(2));
  assertThatBool(([reporters[0] isKindOfClass:[PrettyTextReporter class]]), equalToBool(YES));
  assertThatBool(([reporters[1] isKindOfClass:[PlainTextReporter class]]), equalToBool(YES));
}

- (void)testBuildSettingsAreCollected
{
  NSArray *buildSettings = [[self actionWithArguments:@[@"-configuration", @"Release", @"ABC=123", @"DEF=456"]] buildSettings];
  assertThatInteger(buildSettings.count, equalToInteger(2));
  assertThat(buildSettings, equalTo(@[@"ABC=123", @"DEF=456"]));
}

- (void)testWorkspaceOrProjectAreRequired
{
  [self assertThatValidationWithArgumentList:@[]
                            failsWithMessage:@"Either -workspace or -project must be specified."];
  [self assertThatValidationWithArgumentList:@[
   @"-workspace", @"Something.xcworkspace",
   @"-project", @"Something.xcodeproj"
   ]
                            failsWithMessage:@"Either -workspace or -project must be specified, but not both."];
}

- (void)testSchemeIsRequired
{
  [self assertThatValidationWithArgumentList:@[@"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace"]
                            failsWithMessage:@"Missing the required -scheme argument."];
}

- (void)testWorkspaceMustBeADirectory
{
  [self assertThatValidationWithArgumentList:@[
   @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library-Bogus.xcworkspace",
   @"-scheme", @"SomeScheme",
   ]
                            failsWithMessage:@"Specified workspace doesn't exist: " TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library-Bogus.xcworkspace"];
}

- (void)testProjectMustBeADirectory
{
  [self assertThatValidationWithArgumentList:@[
   @"-project", TEST_DATA @"TestProject-Library/TestProject-Library-Bogus.xcodeproj",
   @"-scheme", @"SomeScheme",
   ]
                            failsWithMessage:@"Specified project doesn't exist: " TEST_DATA @"TestProject-Library/TestProject-Library-Bogus.xcodeproj"];
}

- (void)testSchemeMustBeValid
{
  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);
  // When we're working with projects...
  [self assertThatValidationPassesWithArgumentList:@[
   @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
   @"-scheme", @"TestProject-Library"]];

  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);
  [self assertThatValidationWithArgumentList:@[
   @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
   @"-scheme", @"TestProject-Library-Bogus",
   ]
                            failsWithMessage:@"Can't find scheme 'TestProject-Library-Bogus'. Possible schemes include: TestProject-Library"];

  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);
  // When we're working with workspaces...
  [self assertThatValidationPassesWithArgumentList:@[
   @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
   @"-scheme", @"TestProject-Library"]];

  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);
  [self assertThatValidationWithArgumentList:@[
   @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
   @"-scheme", @"TestProject-Library-Bogus",
   ]
                            failsWithMessage:@"Can't find scheme 'TestProject-Library-Bogus'. Possible schemes include: TestProject-Library"];
}

- (void)testSDKMustBeValid
{
  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);
  [self assertThatValidationPassesWithArgumentList:@[
   @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
   @"-scheme", @"TestProject-Library",
   @"-sdk", @"macosx10.7"]];

  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);
  [self assertThatValidationWithArgumentList:@[
   @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
   @"-scheme", @"TestProject-Library",
   @"-sdk", @"BOGUSSDK",
   ]
                            failsWithMessage:[NSString stringWithFormat:
                                              @"SDK 'BOGUSSDK' doesn't exist.  Possible SDKs include: %@",
                                              [GetAvailableSDKs() componentsJoinedByString:@", "]]];
}

- (void)testArgumentsFlowThroughToCommonXcodebuildArguments
{
  NSArray *arguments = @[@"-configuration", @"SomeConfig",
                         @"-sdk", @"SomeSDK",
                         @"-arch", @"SomeArch",
                         @"-toolchain", @"path/to/some/toolchain",
                         @"-xcconfig", @"some.xcconfig",
                         @"-jobs", @"20",
                         @"SOMEKEY=SOMEVAL",
                         @"SOMEKEY2=SOMEVAL2"
                         ];
  ImplicitAction *action = [self actionWithArguments:arguments];
  assertThat([action commonXcodeBuildArguments], equalTo(arguments));
}

- (void)testXcodeBuildArgumentsForWorkspaceAndSchemeSubject
{
  NSArray *arguments = @[@"-workspace", @"path/to/Something.xcworkspace",
                         @"-scheme", @"Something",
                         ];
  ImplicitAction *action = [self actionWithArguments:arguments];
  assertThat([action xcodeBuildArgumentsForSubject], equalTo(arguments));
}

- (void)testXcodeBuildArgumentsForProjectAndSchemeSubject
{
  NSArray *arguments = @[@"-project", @"path/to/Something.xcodeproj",
                         @"-scheme", @"Something",
                         ];
  ImplicitAction *action = [self actionWithArguments:arguments];
  assertThat([action xcodeBuildArgumentsForSubject], equalTo(arguments));
}

- (void)testDefaultReporterIsPrettyIfNotSpecified
{
  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);
  ImplicitAction *action = [self actionWithArguments:@[
                      @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                      @"-scheme", @"TestProject-Library",
                      ]];
  
  NSString *errorMessage = nil;
  BOOL valid = [action validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease] implicitAction:nil];
  assertThatBool(valid, equalToBool(YES));
  assertThatBool(([action.reporters[0] isKindOfClass:[TextReporter class]]), equalToBool(YES));
}

- (void)testSDKDefaultsToSubjectsSDK
{
  // The subject being the workspace/scheme or project/target we're testing.
  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);

  ImplicitAction *action = [self validatedActionWithArguments:@[
                      @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                      @"-scheme", @"TestProject-Library",
                      ]];
  assertThat(action.sdk, equalTo(@"iphoneos6.1"));
//
//  // If no testSDKs were specified, it should carry through to that, too.
//  assertThat(options.testSDKs, equalTo(@[@"iphoneos6.1"]));
}

@end
