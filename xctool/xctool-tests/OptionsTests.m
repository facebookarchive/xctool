//
// Copyright 2004-present Facebook. All Rights Reserved.
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

#import <XCTest/XCTest.h>

#import "Action.h"
#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "Options+Testing.h"
#import "Options.h"
#import "ReporterTask.h"
#import "RunTestsAction.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"
#import "XcodeSubjectInfo.h"

@interface OptionsTests : XCTestCase
@end

@implementation OptionsTests

- (void)testHelpOptionSetsFlag
{
  assertThatBool([[Options optionsFrom:@[@"-h"]] showHelp], isTrue());
  assertThatBool([[Options optionsFrom:@[@"-help"]] showHelp], isTrue());
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
  assertThat(([[Options optionsFrom:@[@"-destination", @"platform=iOS Simulator"]] destination]), equalTo(@"platform=iOS Simulator"));
  assertThat(([[Options optionsFrom:@[@"-destination-timeout", @"10"]] destinationTimeout]), equalTo(@"10"));
  assertThat(([[Options optionsFrom:@[@"-launch-timeout", @"20"]] launchTimeout]), equalTo(@"20"));
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
  assertThat(([[reporters[0] reporterPath] lastPathComponent]), equalTo(@"pretty"));
  assertThat(([[reporters[1] reporterPath] lastPathComponent]), equalTo(@"plain"));
}

- (void)testBuildSettingsAreCollected
{
  Options *options = [Options optionsFrom:@[
                      @"-configuration", @"Release",
                      @"ABC=123",
                      @"DEF=456"
                      ]];

  NSDictionary *buildSettings = [options buildSettings];
  assertThatInteger(buildSettings.count, equalToInteger(2));
  assertThat(buildSettings,
             equalTo(@{@"ABC" : @"123",
                       @"DEF" : @"456"}));
}

- (void)testDisallowRunTestsWithBothTestsAndWorkspaceAndProject
{
  [[Options optionsFrom:@[
    @"-workspace", @"Something.xcworkspace",
    @"-project", @"Something.xcodeproj",
    @"run-tests",
    @"-logicTest", TEST_DATA @"tests-ios-test-bundle/TestProject-LibraryTests.octest",
    ]]
   assertOptionsFailToValidateWithError:
      @"If -logicTest or -appTest are specified, -workspace, -project, and -scheme must not be specified."];
}

- (void)testDisallowBothWorkspaceAndProjectSpecified
{
  [[Options optionsFrom:@[
    @"-workspace", @"Something.xcworkspace",
    @"-project", @"Something.xcodeproj"
    ]]
   assertOptionsFailToValidateWithError:
   @"Either -workspace or -project can be specified, but not both."];
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

- (void)testWorkspaceMustBeADirectoryThatEndsInXcworkspace
{
  [[Options optionsFrom:@[
                          @"-workspace", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                          @"-scheme", @"TestProject-Library",
                          ]]
   assertOptionsFailToValidateWithError:
   @"Workspace must end in .xcworkspace: " TEST_DATA
   @"TestProject-Library/TestProject-Library.xcodeproj"];
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

- (void)testProjectMustBeADirectoryThatEndsInXcodeProj
{
  [[Options optionsFrom:@[
    @"-project", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
    @"-scheme", @"TestProject-Library",
    ]]
   assertOptionsFailToValidateWithError:
   @"Project must end in .xcodeproj: " TEST_DATA
   @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace"];
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
   @"Can't find scheme 'TestProject-Library-Bogus'.\n\n"
   @"Possible schemes include:\n"
   @"  Target Name With Spaces\n"
   @"  TestProject-Library\n\n"
   @"TIP: This might happen if you're relying on Xcode to autocreate your schemes\n"
   @"and your scheme files don't yet exist.  xctool, like xcodebuild, isn't able to\n"
   @"automatically create schemes.  We recommend disabling \"Autocreate schemes\"\n"
   @"in your workspace/project, making sure your existing schemes are marked as\n"
   @"\"Shared\", and making sure they're checked into source control."
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
   @"Can't find scheme 'TestProject-Library-Bogus'.\n\n"
   @"Possible schemes include:\n"
   @"  TestProject-Library"
   withBuildSettingsFromFile:
   TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"];
}

- (void)testResultBundlePathMustBeADirectory
{
  NSString *validFilePath = TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt";
  [[Options optionsFrom:@[
                          @"-scheme", @"TestProject-Library",
                          @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                          @"-resultBundlePath", validFilePath,
                          ]]
   assertOptionsFailToValidateWithError:
   [NSString stringWithFormat:@"Specified result bundle path must be a directory: %@", validFilePath]];
}

- (void)testResultBundlePathMustExist
{
  NSString *invalidResultBundlePath = @"SOME_BAD_PATH";
  [[Options optionsFrom:@[
                          @"-scheme", @"TestProject-Library",
                          @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                          @"-resultBundlePath", invalidResultBundlePath,
                          ]]
   assertOptionsFailToValidateWithError:
   [NSString stringWithFormat:@"Specified result bundle path doesn't exist: %@", invalidResultBundlePath]];
}

- (void)testResultBundlePathWorks
{
  Options *options = [Options optionsFrom:@[@"-resultBundlePath", @"foo"]];
  assertThat(options.resultBundlePath, equalTo(@"foo"));
}

- (void)testDerivedDataPathWorks
{
  Options *options = [Options optionsFrom:@[@"-derivedDataPath", @"foo"]];
  assertThat(options.derivedDataPath, equalTo(@"foo"));
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
  __block NSString *expectedSDKList = nil;

  // When we GetAvailableSDKsAndAliases() calls xcodebuild, we want it to get
  // the faked output which always has a stable list of SDKs regardless of what
  // SDKs are actually installed.
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    expectedSDKList = [[GetAvailableSDKsAndAliases() allKeys] componentsJoinedByString:@", "];
  }];

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
    expectedSDKList]
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
   @"Reporter with name or path 'blah' could not be found."];
}

- (void)testArgumentsFlowThroughToCommonXcodebuildArguments
{
  NSArray *arguments = @[@"-configuration", @"SomeConfig",
                         @"-sdk", @"SomeSDK",
                         @"-arch", @"SomeArch",
                         @"-destination", @"platform=iOS,OS=6.1",
                         @"-destination-timeout", @"10",
                         @"-toolchain", @"path/to/some/toolchain",
                         @"-xcconfig", @"some.xcconfig",
                         @"-jobs", @"20",
                         @"SOMEKEY=SOMEVAL",
                         @"SOMEKEY2=SOMEVAL2",
                         @"-SomeUserDefault=SomeVal",
                         @"-SomeUserDefault2=SomeVal2",
                         ];
  Options *action = [Options optionsFrom:arguments];
  assertThat([action commonXcodeBuildArgumentsForSchemeAction:nil xcodeSubjectInfo:nil], equalTo(arguments));
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

- (void)testXcodeBuildArgumentsForWorkspaceAndSchemeSubjectWithDerivedData
{
  NSArray *arguments = @[@"-workspace", @"path/to/Something.xcworkspace",
                         @"-scheme", @"Something",
                         @"-derivedDataPath", @"path/to/deriveddata"
                         ];
  Options *action = [Options optionsFrom:arguments];
  assertThat([action xcodeBuildArgumentsForSubject], equalTo(arguments));
}

- (void)testXcodeBuildArgumentsForProjectAndSchemeSubjectWithDerivedData
{
  NSArray *arguments = @[@"-project", @"path/to/Something.xcodeproj",
                         @"-scheme", @"Something",
                         @"-derivedDataPath", @"path/to/deriveddata"
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
  assertThat([[options xcodeBuildArgumentsForSubject]
              arrayByAddingObjectsFromArray:[options commonXcodeBuildArgumentsForSchemeAction:nil xcodeSubjectInfo:nil]],
             equalTo(@[
                     @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                     @"-scheme", @"TestProject-Library",
                     @"-sdk", @"iphonesimulator6.1",
                     @"PLATFORM_NAME=iphonesimulator",
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
  assertThat(([[options.reporters[0] reporterPath] lastPathComponent]), equalTo(@"pretty"));
}

- (void)testHelpOptionSetsPrintUsage
{
  assertThatBool([Options optionsFrom:@[@"-help"]].showHelp, isTrue());
  assertThatBool([Options optionsFrom:@[@"-h"]].showHelp, isTrue());
}

- (void)testActionsAreRecorded
{
  NSArray *(^classNamesFromArray)(NSArray *) = ^(NSArray *arr){
    NSMutableArray *result = [NSMutableArray array];
    for (id item in arr) {
      [result addObject:@(class_getName([item class]))];
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

  assertThatInteger(options.actions.count, equalToInteger(1));
  Action *action = options.actions[0];
  NSString *actionClassName = @(class_getName([action class]));
  assertThat(actionClassName, equalTo(@"BuildAction"));
}

- (void)testBuildOnlyProjectFoundIfNoProjectSpecified
{
  Options *options = [Options optionsFrom:@[@"-scheme", @"TestProject-Library",
                                             ]];
  options.findProjectPath = TEST_DATA @"TestProject-Library";

  [options assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];

  assertThatInteger(options.actions.count, equalToInteger(1));
  Action *action = options.actions[0];
  NSString *actionClassName = @(class_getName([action class]));
  assertThat(actionClassName, equalTo(@"BuildAction"));
}

- (void)testDirectoryMustNotContainMultipleProjectsIfNoProjectSpecified
{
  Options *options = [Options optionsFrom:@[@"-scheme", @"TestMultipleProjectsInDirectory1",
                                            ]];
  options.findProjectPath = TEST_DATA @"TestMultipleProjectsInDirectory";

  [options assertOptionsFailToValidateWithError:
   [NSString stringWithFormat:@"The directory %@ contains 2 projects, including multiple projects with the current "
    "extension (.xcodeproj). Please specify with -workspace, -project, or -find-target.",
    options.findProjectPath]];
}

- (void)testProjectOrWorkspaceRequiredIfNoProjectSpecifiedOrFound
{
  Options *options = [Options optionsFrom:@[@"-scheme", @"TestProject-Library",
                                            ]];
  options.findProjectPath = [[[NSFileManager defaultManager] currentDirectoryPath]
                             stringByAppendingPathComponent:@"xctool-tests/TestData/TestWorkspace-Library"];

  [options assertOptionsFailToValidateWithError:
   [NSString stringWithFormat:@"Unable to find projects (.xcodeproj) in directory %@. Please specify with -workspace, -project, or -find-target.",
    options.findProjectPath]];
}

@end
