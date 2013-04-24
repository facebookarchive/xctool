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

#import <objc/runtime.h>

#import <SenTestingKit/SenTestingKit.h>

#import "Action.h"
#import "FakeTask.h"
#import "Options.h"
#import "TaskUtil.h"
#import "TestUtil.h"
#import "TextReporter.h"
#import "XcodeSubjectInfo.h"
#import "XCToolUtil.h"

@interface OptionsTests : SenTestCase
@end

@implementation OptionsTests

- (void)testHelpOptionSetsFlag
{
  assertThatBool([(Options *)[TestUtil optionsFromArgumentList:@[@"-h"]] showHelp], equalToBool(YES));
  assertThatBool([(Options *)[TestUtil optionsFromArgumentList:@[@"-help"]] showHelp], equalToBool(YES));
}

- (void)testOptionsPassThrough
{
  assertThat(([[TestUtil optionsFromArgumentList:@[@"-configuration", @"SomeConfig"]] configuration]), equalTo(@"SomeConfig"));
  assertThat(([[TestUtil optionsFromArgumentList:@[@"-arch", @"SomeArch"]] arch]), equalTo(@"SomeArch"));
  assertThat(([[TestUtil optionsFromArgumentList:@[@"-sdk", @"SomeSDK"]] sdk]), equalTo(@"SomeSDK"));
  assertThat(([[TestUtil optionsFromArgumentList:@[@"-workspace", @"SomeWorkspace"]] workspace]), equalTo(@"SomeWorkspace"));
  assertThat(([[TestUtil optionsFromArgumentList:@[@"-project", @"SomeProject"]] project]), equalTo(@"SomeProject"));
  assertThat(([[TestUtil optionsFromArgumentList:@[@"-toolchain", @"SomeToolChain"]] toolchain]), equalTo(@"SomeToolChain"));
  assertThat(([[TestUtil optionsFromArgumentList:@[@"-xcconfig", @"something.xcconfig"]] xcconfig]), equalTo(@"something.xcconfig"));
  assertThat(([[TestUtil optionsFromArgumentList:@[@"-jobs", @"10"]] jobs]), equalTo(@"10"));
}

- (void)testReporterOptionsSetupReporters
{
  NSArray *reporters = [[TestUtil validatedReporterOptionsFromArgumentList:@[
                         @"-reporter", @"pretty",
                         @"-reporter", @"plain:out.txt"]] reporters];

  assertThatInteger(reporters.count, equalToInteger(2));
  assertThatBool(([reporters[0] isKindOfClass:[PrettyTextReporter class]]), equalToBool(YES));
  assertThatBool(([reporters[1] isKindOfClass:[PlainTextReporter class]]), equalToBool(YES));
}

- (void)testBuildSettingsAreCollected
{
  NSArray *buildSettings = [[TestUtil optionsFromArgumentList:@[@"-configuration", @"Release", @"ABC=123", @"DEF=456"]] buildSettings];
  assertThatInteger(buildSettings.count, equalToInteger(2));
  assertThat(buildSettings, equalTo(@[@"ABC=123", @"DEF=456"]));
}

- (void)testWorkspaceOrProjectAreRequired
{
  [TestUtil assertThatOptionsValidateWithArgumentList:@[]
                                     failsWithMessage:@"Either -workspace, -project, or -find-target must be specified."];
  [TestUtil assertThatOptionsValidateWithArgumentList:@[
   @"-workspace", @"Something.xcworkspace",
   @"-project", @"Something.xcodeproj"
   ]
                            failsWithMessage:@"Either -workspace or -project must be specified, but not both."];
}

- (void)testSchemeIsRequired
{
  [TestUtil assertThatOptionsValidateWithArgumentList:@[@"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace"]
                            failsWithMessage:@"Missing the required -scheme argument."];
}

- (void)testWorkspaceMustBeADirectory
{
  [TestUtil assertThatOptionsValidateWithArgumentList:@[
   @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library-Bogus.xcworkspace",
   @"-scheme", @"SomeScheme",
   ]
                            failsWithMessage:@"Specified workspace doesn't exist: " TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library-Bogus.xcworkspace"];
}

- (void)testProjectMustBeADirectory
{
  [TestUtil assertThatOptionsValidateWithArgumentList:@[
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
  [TestUtil assertThatOptionsValidateWithArgumentList:@[
   @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
   @"-scheme", @"TestProject-Library"]];

  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);
  [TestUtil assertThatOptionsValidateWithArgumentList:@[
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
  [TestUtil assertThatOptionsValidateWithArgumentList:@[
   @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
   @"-scheme", @"TestProject-Library"]];

  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);
  [TestUtil assertThatOptionsValidateWithArgumentList:@[
   @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
   @"-scheme", @"TestProject-Library-Bogus",
   ]
                            failsWithMessage:@"Can't find scheme 'TestProject-Library-Bogus'. Possible schemes include: TestProject-Library"];
}

- (void)testFindTargetWorks
{
  Options *options = [TestUtil optionsFromArgumentList:@[@"-find-target", @"foo"]];
  assertThat(options.findTarget, equalTo(@"foo"));
}

- (void)testFindTargetPathWorks
{
  Options *options = [TestUtil optionsFromArgumentList:@[@"-find-target", @"foo", @"-find-target-path", @"bar"]];
  assertThat(options.findTarget, equalTo(@"foo"));
  assertThat(options.findTargetPath, equalTo(@"bar"));
}

- (void)testFindTargetPathRequiresFindTarget
{
  [TestUtil assertThatOptionsValidateWithArgumentList:@[@"-workspace", @"blah", @"-find-target-path", @"foo"]
                                     failsWithMessage:@"If -find-target-path is specified, -find-target must be specified."];
}

- (void)testSDKMustBeValid
{
  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);
  [TestUtil assertThatOptionsValidateWithArgumentList:@[
   @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
   @"-scheme", @"TestProject-Library",
   @"-sdk", @"macosx10.7"]];

  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);
  [TestUtil assertThatOptionsValidateWithArgumentList:@[
   @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
   @"-scheme", @"TestProject-Library",
   @"-sdk", @"BOGUSSDK",
   ]
                            failsWithMessage:[NSString stringWithFormat:
                                              @"SDK 'BOGUSSDK' doesn't exist.  Possible SDKs include: %@",
                                              [[GetAvailableSDKsAndAliases() allKeys] componentsJoinedByString:@", "]]];
}

- (void)testReporterMustBeValid
{
  [TestUtil assertThatReporterOptionsValidateWithArgumentList:@[
   @"-reporter", @"pretty"]];
  [TestUtil assertThatReporterOptionsValidateWithArgumentList:@[
   @"-reporter", @"blah",
   ]
                                     failsWithMessage:[NSString stringWithFormat:
                                                       @"No reporter with name 'blah' found."]];
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
  Options *action = [TestUtil optionsFromArgumentList:arguments];
  assertThat([action commonXcodeBuildArguments], equalTo(arguments));
}

- (void)testXcodeBuildArgumentsForWorkspaceAndSchemeSubject
{
  NSArray *arguments = @[@"-workspace", @"path/to/Something.xcworkspace",
                         @"-scheme", @"Something",
                         ];
  Options *action = [TestUtil optionsFromArgumentList:arguments];
  assertThat([action xcodeBuildArgumentsForSubject], equalTo(arguments));
}

- (void)testXcodeBuildArgumentsForProjectAndSchemeSubject
{
  NSArray *arguments = @[@"-project", @"path/to/Something.xcodeproj",
                         @"-scheme", @"Something",
                         ];
  Options *action = [TestUtil optionsFromArgumentList:arguments];
  assertThat([action xcodeBuildArgumentsForSubject], equalTo(arguments));
}

- (void)testCanSpecifyLatestInsteadOfSpecificSDKVersion
{
  ReturnFakeTasks(@[
                  [FakeTask fakeTaskWithExitStatus:0
                                standardOutputPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                                 standardErrorPath:nil]
                  ]);

  NSArray *arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                         @"-scheme", @"TestProject-Library",
                         @"-sdk", @"iphonesimulator",
                         ];
  Options *action = [TestUtil validatedOptionsFromArgumentList:arguments];
  assertThat([action xcodeBuildArgumentsForSubject],
             equalTo(@[
                     @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"-configuration", @"Release",
                     @"-sdk", @"iphonesimulator6.1",
                     ]));
}

- (void)testDefaultReporterIsPrettyIfNotSpecified
{
  Options *action = [TestUtil optionsFromArgumentList:@[
                      @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                      @"-scheme", @"TestProject-Library",
                      ]];

  NSString *errorMessage = nil;
  BOOL valid = [action validateReporterOptions:&errorMessage];
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

  Options *action = [TestUtil validatedOptionsFromArgumentList:@[
                      @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                      @"-scheme", @"TestProject-Library",
                      ]];
  assertThat(action.sdk, equalTo(@"iphoneos6.1"));
}

- (void)testHelpOptionSetsPrintUsage
{
  assertThatBool([TestUtil optionsFromArgumentList:@[@"-help"]].showHelp, equalToBool(YES));
}

- (void)testShortHelpOptionSetsPrintUsage
{
  assertThatBool([TestUtil optionsFromArgumentList:@[@"-h"]].showHelp, equalToBool(YES));
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

  assertThat(classNamesFromArray([TestUtil optionsFromArgumentList:@[
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

  Options *options = [TestUtil validatedOptionsFromArgumentList:@[
                      @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                      @"-scheme", @"TestProject-Library",
                      ]];

  assertThatInteger(options.actions.count, equalToInteger(1));
  Action *action = options.actions[0];
  NSString *actionClassName = [NSString stringWithUTF8String:class_getName([action class])];
  assertThat(actionClassName, equalTo(@"BuildAction"));
}

@end
