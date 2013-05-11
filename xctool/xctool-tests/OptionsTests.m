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
#import "NSTask+Testing.h"
#import "Options.h"
#import "Options+Testing.h"
#import "TaskUtil.h"
#import "TextReporter.h"
#import "XcodeSubjectInfo.h"
#import "XCToolUtil.h"

@interface OptionsTests : SenTestCase
@end

@implementation OptionsTests

- (void)testHelpOptionSetsFlag
{
  assertThatBool([[Options optionsFrom:@[@"-h"]] showHelp], equalToBool(YES));
  assertThatBool([[Options optionsFrom:@[@"-help"]] showHelp], equalToBool(YES));
}

- (void)testOptionsPassThrough
{
  assertThat(([[Options optionsFrom:@[@"-configuration", @"SomeConfig"]] configuration]), equalTo(@"SomeConfig"));
  assertThat(([[Options optionsFrom:@[@"-arch", @"SomeArch"]] arch]), equalTo(@"SomeArch"));
  assertThat(([[Options optionsFrom:@[@"-sdk", @"SomeSDK"]] sdk]), equalTo(@"SomeSDK"));
  assertThat(([[Options optionsFrom:@[@"-workspace", @"SomeWorkspace"]] workspace]), equalTo(@"SomeWorkspace"));
  assertThat(([[Options optionsFrom:@[@"-project", @"SomeProject"]] project]), equalTo(@"SomeProject"));
  assertThat(([[Options optionsFrom:@[@"-toolchain", @"SomeToolChain"]] toolchain]), equalTo(@"SomeToolChain"));
  assertThat(([[Options optionsFrom:@[@"-xcconfig", @"something.xcconfig"]] xcconfig]), equalTo(@"something.xcconfig"));
  assertThat(([[Options optionsFrom:@[@"-jobs", @"10"]] jobs]), equalTo(@"10"));
}

- (void)testReporterOptionsSetupReporters
{
  Options *options = [Options optionsFrom:@[
                         @"-reporter", @"pretty",
                         @"-reporter", @"plain:out.txt"
                      ]];
  [options assertReporterOptionsValidate];

  NSArray *reporters = [options reporters];
  assertThatInteger([reporters count], equalToInteger(2));
  assertThatBool(([reporters[0] isKindOfClass:[PrettyTextReporter class]]), equalToBool(YES));
  assertThatBool(([reporters[1] isKindOfClass:[PlainTextReporter class]]), equalToBool(YES));
}

- (void)testBuildSettingsAreCollected
{
  Options *options = [Options optionsFrom:@[
                      @"-configuration", @"Release",
                      @"ABC=123",
                      @"DEF=456"
                      ]];

  NSArray *buildSettings = [options buildSettings];
  assertThatInteger(buildSettings.count, equalToInteger(2));
  assertThat(buildSettings, equalTo(@[@"ABC=123", @"DEF=456"]));
}

- (void)testWorkspaceOrProjectAreRequired
{
  [[Options optionsFrom:@[]]
   assertOptionsFailToValidateWithError:
   @"Either -workspace, -project, or -find-target must be specified."];

  [[Options optionsFrom:@[
    @"-workspace", @"Something.xcworkspace",
    @"-project", @"Something.xcodeproj"
    ]]
   assertOptionsFailToValidateWithError:
   @"Either -workspace or -project must be specified, but not both."];
}

- (void)testSchemeIsRequired
{
  [[Options optionsFrom:@[
    @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace"
    ]]
   assertOptionsFailToValidateWithError:
   @"Missing the required -scheme argument."];
}

- (void)testWorkspaceMustBeADirectory
{
  [[Options optionsFrom:@[
    @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library-Bogus.xcworkspace",
    @"-scheme", @"SomeScheme",
    ]]
   assertOptionsFailToValidateWithError:
   @"Specified workspace doesn't exist: " TEST_DATA
   @"TestWorkspace-Library/TestWorkspace-Library-Bogus.xcworkspace"];
}

- (void)testProjectMustBeADirectory
{
  [[Options optionsFrom:@[
    @"-project", TEST_DATA @"TestProject-Library/TestProject-Library-Bogus.xcodeproj",
    @"-scheme", @"SomeScheme",
    ]]
   assertOptionsFailToValidateWithError:
   @"Specified project doesn't exist: " TEST_DATA
   @"TestProject-Library/TestProject-Library-Bogus.xcodeproj"];
}

- (void)testSchemeMustBeValid
{
  // When we're working with projects...
  [[Options optionsFrom:@[
   @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
   @"-scheme", @"TestProject-Library"
   ]]
   assertOptionsValidateWithBuildSettingsFromFile:
   TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"];

  [[Options optionsFrom:@[
    @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
    @"-scheme", @"TestProject-Library-Bogus",
    ]]
   assertOptionsFailToValidateWithError:
   @"Can't find scheme 'TestProject-Library-Bogus'. Possible schemes include: TestProject-Library"
   withBuildSettingsFromFile:
   TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"];


  // When we're working with workspaces...
  [[Options optionsFrom:@[
    @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
    @"-scheme", @"TestProject-Library"
    ]]
   assertOptionsValidateWithBuildSettingsFromFile:
   TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"];

  [[Options optionsFrom:@[
    @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
    @"-scheme", @"TestProject-Library-Bogus",
    ]]
   assertOptionsFailToValidateWithError:
   @"Can't find scheme 'TestProject-Library-Bogus'. Possible schemes include: TestProject-Library"
   withBuildSettingsFromFile:
   TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"];
}

- (void)testFindTargetWorks
{
  Options *options = [Options optionsFrom:@[@"-find-target", @"foo"]];
  assertThat(options.findTarget, equalTo(@"foo"));
}

- (void)testFindTargetPathWorks
{
  Options *options = [Options optionsFrom:@[@"-find-target", @"foo", @"-find-target-path", @"bar"]];
  assertThat(options.findTarget, equalTo(@"foo"));
  assertThat(options.findTargetPath, equalTo(@"bar"));
}

- (void)testFindTargetPathRequiresFindTarget
{
  [[Options optionsFrom:@[@"-workspace", @"blah", @"-find-target-path", @"foo"]]
   assertOptionsFailToValidateWithError:@"If -find-target-path is specified, -find-target must be specified."];
}

- (void)testSDKMustBeValid
{
  [[Options optionsFrom:@[
    @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
    @"-scheme", @"TestProject-Library",
    @"-sdk", @"macosx10.7",
    ]]
   assertOptionsValidateWithBuildSettingsFromFile:
   TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"];

  [[Options optionsFrom:@[
    @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
    @"-scheme", @"TestProject-Library",
    @"-sdk", @"BOGUSSDK",
    ]]
   assertOptionsFailToValidateWithError:
   [NSString stringWithFormat:
    @"SDK 'BOGUSSDK' doesn't exist.  Possible SDKs include: %@",
    [[GetAvailableSDKsAndAliases() allKeys] componentsJoinedByString:@", "]]
   withBuildSettingsFromFile:
   TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"];
}

- (void)testReporterMustBeValid
{
  [[Options optionsFrom:@[
    @"-reporter", @"pretty"
    ]] assertReporterOptionsValidate];

  [[Options optionsFrom:@[
    @"-reporter", @"blah"
    ]] assertReporterOptionsFailToValidateWithError:
   @"No reporter with name 'blah' found."];
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
  Options *action = [Options optionsFrom:arguments];
  assertThat([action commonXcodeBuildArguments], equalTo(arguments));
}

- (void)testXcodeBuildArgumentsForWorkspaceAndSchemeSubject
{
  NSArray *arguments = @[@"-workspace", @"path/to/Something.xcworkspace",
                         @"-scheme", @"Something",
                         ];
  Options *action = [Options optionsFrom:arguments];
  assertThat([action xcodeBuildArgumentsForSubject], equalTo(arguments));
}

- (void)testXcodeBuildArgumentsForProjectAndSchemeSubject
{
  NSArray *arguments = @[@"-project", @"path/to/Something.xcodeproj",
                         @"-scheme", @"Something",
                         ];
  Options *action = [Options optionsFrom:arguments];
  assertThat([action xcodeBuildArgumentsForSubject], equalTo(arguments));
}

- (void)testCanSpecifyLatestInsteadOfSpecificSDKVersion
{
  Options *options = [[Options optionsFrom:@[
                      @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                      @"-scheme", @"TestProject-Library",
                      @"-sdk", @"iphonesimulator",
                      ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  assertThat([options xcodeBuildArgumentsForSubject],
             equalTo(@[
                     @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"-configuration", @"Release",
                     @"-sdk", @"iphonesimulator6.1",
                     ]));
}

- (void)testDefaultReporterIsPrettyIfNotSpecified
{
  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  assertThatBool(([options.reporters[0] isKindOfClass:[TextReporter class]]),
                 equalToBool(YES));
}

- (void)testSDKDefaultsToSubjectsSDK
{
  // The subject being the workspace/scheme or project/target we're testing.
  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  assertThat(options.sdk, equalTo(@"iphoneos6.1"));
}

- (void)testHelpOptionSetsPrintUsage
{
  assertThatBool([Options optionsFrom:@[@"-help"]].showHelp, equalToBool(YES));
  assertThatBool([Options optionsFrom:@[@"-h"]].showHelp, equalToBool(YES));
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

  assertThat(classNamesFromArray([Options optionsFrom:@[
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
  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  assertThat(options.sdk, equalTo(@"iphoneos6.1"));

  assertThatInteger(options.actions.count, equalToInteger(1));
  Action *action = options.actions[0];
  NSString *actionClassName = [NSString stringWithUTF8String:class_getName([action class])];
  assertThat(actionClassName, equalTo(@"BuildAction"));
}

@end
