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

#import <Foundation/Foundation.h>

#import <XCTest/XCTest.h>

#import "ContainsArray.h"
#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "LaunchHandlers.h"
#import "Options+Testing.h"
#import "Testable.h"
#import "XCToolUtil.h"
#import "XcodeSubjectInfo.h"
#import "XcodeTargetMatch.h"

@interface XcodeSubjectInfo (Testing)
- (void)populateBuildablesAndTestablesForWorkspaceWithSchemePath:(NSString *)schemePath;
- (NSString *)matchingSchemePathForWorkspace;
- (NSString *)matchingSchemePathForProject;
@end

@interface XcodeSubjectInfoTests : XCTestCase
@end

@implementation XcodeSubjectInfoTests

#pragma mark - Helpers

+ (NSString *)createScheme:(NSString *)schemeName inContainer:(NSString *)containerPath shared:(BOOL)shared username:(NSString *)username
{
  // create a scheme for a currently logged in user
  NSString *middlePath = nil;
  if (shared) {
    middlePath = @"xcshareddata";
  } else {
    middlePath = [NSString pathWithComponents:@[
      @"xcuserdata",
      [username ?: NSUserName() stringByAppendingPathExtension:@"xcuserdatad"],
    ]];
  }
  NSString *schemePath = [NSString pathWithComponents:@[
    containerPath,
    middlePath,
    @"xcschemes",
    schemeName,
  ]];
  NSError *error = nil;
  // create directories if needed
  BOOL schemeCreated = [[NSFileManager defaultManager] createDirectoryAtPath:[schemePath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
  NSAssert(schemeCreated, @"Test scheme creation failed with error: %@", error);
  // remove scheme if it was created previously
  [[NSFileManager defaultManager] removeItemAtPath:schemePath error:&error];
  // create a new test scheme
  schemeCreated = [[NSFileManager defaultManager] createFileAtPath:schemePath contents:[@"" dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
  NSAssert(schemeCreated, @"Test scheme creation failed.");

  return schemePath;
}

+ (void)removeSchemeAtPath:(NSString *)schemePath
{
  // remove a test scheme
  NSError *error;
  BOOL removed = [[NSFileManager defaultManager] removeItemAtPath:schemePath error:&error];
  NSAssert(removed, @"Failed to remove test scheme at path: %@ with error: %@", schemePath, error);
}

#pragma mark - Tests

- (void)testCanGetProjectPathsInWorkspace
{
  NSArray *paths = [XcodeSubjectInfo projectPathsInWorkspace:TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace"];
  assertThat(paths, equalTo(@[TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj"]));
}

- (void)testCanGetProjectPathsInWorkspaceWhenPathsAreRelativeToGroups
{
  // In contents.xcworkspacedata, FileRefs can have paths relative to the groups they're within.
  NSSet *paths = [NSSet setWithArray:[XcodeSubjectInfo projectPathsInWorkspace:TEST_DATA @"WorkspacePathTest/NestedDir/SomeWorkspace.xcworkspace"]];
  assertThat(paths,
             equalTo([NSSet setWithArray:@[
                     TEST_DATA @"WorkspacePathTest/OtherNestedDir/OtherProject/OtherProject.xcodeproj",
                     TEST_DATA @"WorkspacePathTest/NestedDir/SomeProject/SomeProject.xcodeproj"]]));
}

- (void)testCanGetProjectPathsInProjectWithNestedProjects
{
  NSArray *paths = [XcodeSubjectInfo projectPathsInWorkspace:TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes.xcodeproj/project.xcworkspace"];
  // we can't be sure about order because PbxprojReader returns sets.
  assertThatInteger(paths.count, equalToInteger(4));
  assertThat([NSSet setWithArray:paths], equalTo([NSSet setWithArray:@[
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/InternalProjectLibraryA/InternalProjectLibraryA.xcodeproj",
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes/OtherProjects/InternalProjectLibraryB/InternalProjectLibraryB.xcodeproj",
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/InternalProjectLibraryC/HideProjectFolder/WhyNotMore/InternalProjectLibraryC.xcodeproj",
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes.xcodeproj",
  ]]));
}

- (void)testCanGetAllSchemesInAProjectIncludingCurrentlyLoggedInUserOne
{
  NSString *projectPath = TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj";
  // create a scheme for a currently logged in user
  NSString *schemePath = [XcodeSubjectInfoTests createScheme:@"XCTOOL_TEST_SCHEME.xcscheme"
                                                 inContainer:projectPath
                                                      shared:NO
                                                    username:nil];

  NSSet *schemes = [NSSet setWithArray:[XcodeSubjectInfo schemePathsInContainer:projectPath]];
  assertThat(schemes, equalTo([NSSet setWithArray:@[
    TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj/xcshareddata/xcschemes/Target Name With Spaces.xcscheme",
    TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj/xcshareddata/xcschemes/TestProject-Library.xcscheme",
    schemePath,
  ]]));

  // remove a test scheme
  [XcodeSubjectInfoTests removeSchemeAtPath:schemePath];
}

- (void)testCanGetAllSchemesInAWorkspaceIgnoringNotCurrentlyLoggedUserSchemes
{
  NSString *workspacePath = TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace";
  // create a scheme for a currently logged in user
  NSString *schemePath = [XcodeSubjectInfoTests createScheme:@"XCTOOL_TEST_SCHEME.xcscheme"
                                                 inContainer:workspacePath
                                                      shared:NO
                                                    username:[NSUserName() stringByAppendingString:@"_xctool"]];

  NSArray *schemes = [XcodeSubjectInfo schemePathsInWorkspace:workspacePath];
  assertThat(schemes, equalTo(@[
    TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj/xcshareddata/xcschemes/TestProject-Library.xcscheme",
  ]));

  // remove test scheme
  [XcodeSubjectInfoTests removeSchemeAtPath:schemePath];
}

- (void)testCanGetAllSchemesInAProjectWithNestedProjects
{
  NSArray *schemes = [XcodeSubjectInfo schemePathsInWorkspace:TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes.xcodeproj/project.xcworkspace"];
  // we can't be sure about order because PbxprojReader returns sets.
  assertThatInteger(schemes.count, equalToInteger(6));
  assertThat([NSSet setWithArray:schemes], equalTo([NSSet setWithArray:@[
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes.xcodeproj/xcshareddata/xcschemes/TestProject-RecursiveProjectsAndSchemes.xcscheme",
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes.xcodeproj/xcshareddata/xcschemes/TestProject-RecursiveProjectsAndSchemes-InternalTests.xcscheme",
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/InternalProjectLibraryA/InternalProjectLibraryA.xcodeproj/xcshareddata/xcschemes/InternalProjectLibraryA.xcscheme",
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes/OtherProjects/InternalProjectLibraryB/InternalProjectLibraryB.xcodeproj/xcshareddata/xcschemes/InternalProjectLibraryB.xcscheme",
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/InternalProjectLibraryC/HideProjectFolder/WhyNotMore/InternalProjectLibraryC.xcodeproj/xcshareddata/xcschemes/InternalProjectLibraryC.xcscheme",
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/InternalProjectLibraryC/HideProjectFolder/WhyNotMore/InternalProjectLibraryC.xcodeproj/xcshareddata/xcschemes/InternalProjectLibraryTests.xcscheme",
  ]]));
}

- (void)testCanGetAllSchemesInAWorkspaceWithNestedProjects
{
  NSArray *schemes = [XcodeSubjectInfo schemePathsInWorkspace:TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes.xcworkspace"];
  // we can't be sure about order because PbxprojReader returns sets.
  assertThatInteger(schemes.count, equalToInteger(7));
  assertThat([NSSet setWithArray:schemes], equalTo([NSSet setWithArray:@[
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes.xcworkspace/xcshareddata/xcschemes/WorkspaceInternalProjectLibraryTests.xcscheme",
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes.xcodeproj/xcshareddata/xcschemes/TestProject-RecursiveProjectsAndSchemes.xcscheme",
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes.xcodeproj/xcshareddata/xcschemes/TestProject-RecursiveProjectsAndSchemes-InternalTests.xcscheme",
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/InternalProjectLibraryA/InternalProjectLibraryA.xcodeproj/xcshareddata/xcschemes/InternalProjectLibraryA.xcscheme",
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes/OtherProjects/InternalProjectLibraryB/InternalProjectLibraryB.xcodeproj/xcshareddata/xcschemes/InternalProjectLibraryB.xcscheme",
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/InternalProjectLibraryC/HideProjectFolder/WhyNotMore/InternalProjectLibraryC.xcodeproj/xcshareddata/xcschemes/InternalProjectLibraryC.xcscheme",
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/InternalProjectLibraryC/HideProjectFolder/WhyNotMore/InternalProjectLibraryC.xcodeproj/xcshareddata/xcschemes/InternalProjectLibraryTests.xcscheme",
  ]]));
}

- (void)testCanGetAllSchemesInAWorkspace_ProjectContainers
{
  // In the Manage Schemes dialog, you can choose to locate your scheme under a project.  Here
  // we test that case.
  NSArray *schemes = [XcodeSubjectInfo schemePathsInWorkspace:TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace"];
  assertThat(schemes, equalTo(@[TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj/xcshareddata/xcschemes/TestProject-Library.xcscheme"]));
}

- (void)testCanGetAllSchemesInAWorkspace_WorkspaceContainers
{
  // In the Manage Schemes dialog, you can choose to locate your scheme under a workspace.  Here
  // we test that case.
  NSArray *schemes = [XcodeSubjectInfo schemePathsInWorkspace:TEST_DATA @"SchemeInWorkspaceContainer/SchemeInWorkspaceContainer.xcworkspace"];
  assertThat(schemes, equalTo(@[TEST_DATA @"SchemeInWorkspaceContainer/SchemeInWorkspaceContainer.xcworkspace/xcshareddata/xcschemes/SomeLibrary.xcscheme"]));
}

- (void)testUserDefinedSchemeIsReturnedWhenSharedOneWithTheSameNameExistsInWorkspace
{
  NSString *workspacePath = TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace";
  NSString *schemeName = [NSString stringWithFormat:@"SchemeForTest_%@", NSStringFromSelector(_cmd)];
  // create a scheme for a currently logged in user
  NSString *userSchemePath = [XcodeSubjectInfoTests createScheme:[schemeName stringByAppendingPathExtension:@"xcscheme"]
                                                     inContainer:workspacePath
                                                          shared:NO
                                                        username:nil];
  // create a shared scheme
  NSString *sharedSchemePath = [XcodeSubjectInfoTests createScheme:[schemeName stringByAppendingPathExtension:@"xcscheme"]
                                                       inContainer:workspacePath
                                                            shared:YES
                                                          username:nil];

  XcodeSubjectInfo *info = [[XcodeSubjectInfo alloc] init];
  info.subjectWorkspace = workspacePath;
  info.subjectScheme = schemeName;
  NSArray *schemes = [XcodeSubjectInfo schemePathsInWorkspace:workspacePath];
  assertThat(schemes, containsArray(@[sharedSchemePath, userSchemePath]));

  assertThat([info matchingSchemePathForWorkspace], equalTo(userSchemePath));

  [XcodeSubjectInfoTests removeSchemeAtPath:userSchemePath];
  [XcodeSubjectInfoTests removeSchemeAtPath:sharedSchemePath];
}

- (void)testUserDefinedSchemeIsReturnedWhenSharedOneWithTheSameNameExistsInProject
{
  NSString *projectPath = TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj";
  NSString *schemeName = [NSString stringWithFormat:@"SchemeForTest_%@", NSStringFromSelector(_cmd)];
  // create a scheme for a currently logged in user
  NSString *userSchemePath = [XcodeSubjectInfoTests createScheme:[schemeName stringByAppendingPathExtension:@"xcscheme"]
                                                     inContainer:projectPath
                                                          shared:NO
                                                        username:nil];
  // create a shared scheme
  NSString *sharedSchemePath = [XcodeSubjectInfoTests createScheme:[schemeName stringByAppendingPathExtension:@"xcscheme"]
                                                       inContainer:projectPath
                                                            shared:YES
                                                          username:nil];

  XcodeSubjectInfo *info = [[XcodeSubjectInfo alloc] init];
  info.subjectWorkspace = projectPath;
  info.subjectScheme = schemeName;
  NSArray *schemes = [XcodeSubjectInfo schemePathsInContainer:projectPath];
  assertThat(schemes, containsArray(@[
    sharedSchemePath,
    TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj/xcshareddata/xcschemes/Target Name With Spaces.xcscheme",
    TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj/xcshareddata/xcschemes/TestProject-Library.xcscheme",
    userSchemePath
  ]));

  assertThat([info matchingSchemePathForWorkspace], equalTo(userSchemePath));

  [XcodeSubjectInfoTests removeSchemeAtPath:userSchemePath];
  [XcodeSubjectInfoTests removeSchemeAtPath:sharedSchemePath];
}

/**
 As of Xcode4, even plain projects have a workspace.  If you have SomeProj.xcodeproj, you'll have
 a workspace nested at SomeProj.xcodeproj/contents.xcworkspace.

 Since the top-level unit is a project, you'd normally invoke xctool like --

    xctool -project SomeProj.xcodeproj -scheme SomeScheme

 But, what if you did something funky like --

    xctool -workspace SomeProj.xcodeproj/project.xcworkspace -scheme SomeScheme

 This test makes sure we don't barf in that case - we have some build scripts that actually do this.
 It turns out nested xcworkspace's specify locations to projects in a different way (i.e. they'll
 use a 'self:' prefix in the location field).
 */
- (void)testCanAcceptNestedWorkspaceLikeARealWorkspace
{
  // With Xcode, even plain projects have a workspace - it's just nested within the xcodeprojec
  NSArray *paths = [XcodeSubjectInfo projectPathsInWorkspace:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj/project.xcworkspace"];
  assertThat(paths, equalTo(@[TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"]));
}

- (void)testFindProject
{
  XcodeTargetMatch *match;
  BOOL ret = [XcodeSubjectInfo findTarget:@"TestProject-LibraryTests"
                              inDirectory:TEST_DATA @"TestWorkspace-Library/TestProject-Library"
                             excludePaths:@[]
                          bestTargetMatch:&match];
  assertThatBool(ret, isTrue());
  assertThat(match.workspacePath, equalTo(nil));
  assertThat(
    match.projectPath,
    containsString(@"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj"));
  assertThat(match.schemeName, equalTo(@"TestProject-Library"));
}

- (void)testFindWorkspacePreferredOverProject
{
  XcodeTargetMatch *match;
  BOOL ret = [XcodeSubjectInfo findTarget:@"TestProject-LibraryTests"
                              inDirectory:TEST_DATA @"TestWorkspace-Library"
                             excludePaths:@[]
                          bestTargetMatch:&match];
  assertThatBool(ret, isTrue());
  assertThat(
    match.workspacePath,
    containsString(@"TestWorkspace-Library/TestWorkspace-Library.xcworkspace"));
  assertThat(
    match.projectPath,
    equalTo(nil));
  assertThat(match.schemeName, equalTo(@"TestProject-Library"));
}

- (void)testCanParseBuildSettingsWithSpacesInTheName
{
  NSString *output = [NSString stringWithContentsOfFile:TEST_DATA @"TargetNamesWithSpaces-showBuildSettings.txt"
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
  NSDictionary *settings = BuildSettingsFromOutput(output);
  assertThat([settings allKeys][0], equalTo(@"Target Name With Spaces"));
}

- (void)testCanParseBuildSettingsWithUserDefaults
{
  NSString *output = [NSString stringWithContentsOfFile:TEST_DATA @"BuildSettingsWithUserDefaults.txt"
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
  NSDictionary *settings = BuildSettingsFromOutput(output);
  assertThatBool([[settings allKeys] count] > 0, isTrue());
}

- (void)testCanParseBuildSettingsWithConfigurationFile
{
  NSString *configOutput = [NSString stringWithContentsOfFile:TEST_DATA @"BuildSettingsWithConfigurationFile.txt"
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
  NSDictionary *settings = BuildSettingsFromOutput(configOutput);
  NSAssert([settings count] == 1,
           @"Should only have build settings for a single target.");
}

- (void)testCanParseTestablesFromScheme
{
  NSArray *testables = [XcodeSubjectInfo testablesInSchemePath:
   TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj/xcshareddata/"
   @"xcschemes/TestProject-Library.xcscheme"
                                 basePath:
   TEST_DATA @"TestProject-Library"
   ];

  assertThatInteger(testables.count, equalToInteger(1));
  Testable *testable = testables[0];
  assertThat(testable.arguments, equalTo(@[]));
  assertThat(testable.environment, equalTo(@{}));
  assertThat(testable.executable, equalTo(@"TestProject-LibraryTests.octest"));
  assertThat(testable.projectPath, endsWith(@"xctool-tests/TestData/TestProject-Library/TestProject-Library.xcodeproj"));
  assertThat(testable.skippedTests, equalTo(@[@"DisabledTests"]));
  assertThatBool(testable.skipped, isFalse());
  assertThat(testable.target, equalTo(@"TestProject-LibraryTests"));
  assertThat(testable.targetID, equalTo(@"2828293016B11F0F00426B92"));
}

/**
 * Xcode's default is to run your test with the same command-line arguments
 * and environment settings you've assigned in the "Run" action of your scheme.
 */
- (void)testTestablesIncludeArgsAndEnvFromRunAction
{
  NSArray *testables = [XcodeSubjectInfo testablesInSchemePath:
                        TEST_DATA @"TestsWithArgAndEnvSettingsInRunAction/"
                        @"TestsWithArgAndEnvSettings.xcodeproj/xcshareddata/"
                        @"xcschemes/TestsWithArgAndEnvSettings.xcscheme"
                                                      basePath:
                        TEST_DATA @"TestsWithArgAndEnvSettingsInRunAction"
                        ];

  assertThatInteger(testables.count, equalToInteger(1));
  Testable *testable = testables[0];
  assertThat(testable.arguments, equalTo(@[@"-RunArg", @"RunArgValue"]));
  assertThat(testable.environment, equalTo(@{@"RunEnvKey" : @"RunEnvValue"}));
  assertThat(testable.macroExpansionProjectPath, equalTo(nil));
  assertThat(testable.macroExpansionTarget, equalTo(nil));
  assertThat(testable.executable, equalTo(@"TestsWithArgAndEnvSettingsTests.octest"));
  assertThat(testable.projectPath, endsWith(@"xctool-tests/TestData/TestsWithArgAndEnvSettingsInRunAction/TestsWithArgAndEnvSettings.xcodeproj"));
  assertThat(testable.skippedTests, equalTo(@[]));
  assertThatBool(testable.skipped, isFalse());
  assertThat(testable.target, equalTo(@"TestsWithArgAndEnvSettingsTests"));
  assertThat(testable.targetID, equalTo(@"288DD482173B7C9800F1093C"));
}

/**
 * Xcode's default is to run your test with the same command-line arguments
 * and environment settings you've assigned in the "Run" action of your scheme,
 * BUT you can also specify explicit arg/env settings just for tests.
 */
- (void)testTestablesIncludeArgsAndEnvFromTestAction
{
  NSArray *testables = [XcodeSubjectInfo testablesInSchemePath:
                        TEST_DATA @"TestsWithArgAndEnvSettingsInTestAction/"
                        @"TestsWithArgAndEnvSettings.xcodeproj/xcshareddata/"
                        @"xcschemes/TestsWithArgAndEnvSettings.xcscheme"
                                                      basePath:
                        TEST_DATA @"TestsWithArgAndEnvSettingsInTestAction"
                        ];

  assertThatInteger(testables.count, equalToInteger(1));
  Testable *testable = testables[0];
  assertThat(testable.arguments, equalTo(@[@"-TestArg", @"TestArgValue"]));
  assertThat(testable.environment, equalTo(@{@"TestEnvKey" : @"TestEnvValue"}));
  assertThat(testable.macroExpansionProjectPath, equalTo(nil));
  assertThat(testable.macroExpansionTarget, equalTo(nil));
  assertThat(testable.executable, equalTo(@"TestsWithArgAndEnvSettingsTests.octest"));
  assertThat(testable.projectPath, endsWith(@"xctool-tests/TestData/TestsWithArgAndEnvSettingsInTestAction/TestsWithArgAndEnvSettings.xcodeproj"));
  assertThat(testable.skippedTests, equalTo(@[]));
  assertThatBool(testable.skipped, isFalse());
  assertThat(testable.target, equalTo(@"TestsWithArgAndEnvSettingsTests"));
  assertThat(testable.targetID, equalTo(@"288DD482173B7C9800F1093C"));
}

/**
 The macro expansion is what lets arguments or environment contain $(VARS) that
 get exanded based on the build settings.
 */
- (void)testTestableIncludesInfoForMacroExpansion
{
  NSArray *testables = [XcodeSubjectInfo testablesInSchemePath:
                        TEST_DATA @"TestsWithArgAndEnvSettingsWithMacroExpansion/"
                        @"TestsWithArgAndEnvSettings.xcodeproj/xcshareddata/"
                        @"xcschemes/TestsWithArgAndEnvSettings.xcscheme"
                                                      basePath:
                        TEST_DATA @"TestsWithArgAndEnvSettingsWithMacroExpansion"
                        ];

  assertThatInteger(testables.count, equalToInteger(1));
  Testable *testable = testables[0];
  assertThat(testable.arguments, equalTo(@[]));
  assertThat(testable.environment, equalTo(@{
                                             @"RunEnvKey" : @"RunEnvValue",
                                             @"ARCHS" : @"$(ARCHS)",
                                             @"DYLD_INSERT_LIBRARIES" : @"ThisShouldNotGetOverwrittenByOtestShim",
                                             }));
  assertThat(testable.macroExpansionProjectPath, endsWith(@"xctool-tests/TestData/TestsWithArgAndEnvSettingsWithMacroExpansion/TestsWithArgAndEnvSettings.xcodeproj"));
  assertThat(testable.macroExpansionTarget, equalTo(@"TestsWithArgAndEnvSettings"));
  assertThat(testable.executable, equalTo(@"TestsWithArgAndEnvSettingsTests.octest"));
  assertThat(testable.projectPath, endsWith(@"xctool-tests/TestData/TestsWithArgAndEnvSettingsWithMacroExpansion/TestsWithArgAndEnvSettings.xcodeproj"));
  assertThat(testable.skippedTests, equalTo(@[]));
  assertThatBool(testable.skipped, isFalse());
  assertThat(testable.target, equalTo(@"TestsWithArgAndEnvSettingsTests"));
  assertThat(testable.targetID, equalTo(@"288DD482173B7C9800F1093C"));
}

- (XcodeSubjectInfo *)xcodeSubjectInfoPopulatedWithProject:(NSString *)project scheme:(NSString *)scheme
{
  __block XcodeSubjectInfo *subjectInfo = nil;

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj"
                                                     scheme:@"TestProject-Library"
                                               settingsPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"],
     ]];

    Options *options = [Options optionsFrom:@[
                        @"-project", TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj",
                        @"-scheme", @"TestProject-Library",
                        ]];

    subjectInfo = [[XcodeSubjectInfo alloc] init];
    [subjectInfo setSubjectProject:[options project]];
    [subjectInfo setSubjectScheme:[options scheme]];
    [subjectInfo setSubjectXcodeBuildArguments:[options xcodeBuildArgumentsForSubject]];

    [subjectInfo loadSubjectInfo];
  }];

  return subjectInfo;
}

- (void)testCanGetBuildConfigurationForRunAction
{
  XcodeSubjectInfo *subjectInfo =
    [self xcodeSubjectInfoPopulatedWithProject:TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj"
                                        scheme:@"TestProject-Library"];

  // The project has a different configuration set for each scheme action.
  assertThat([subjectInfo configurationNameForAction:@"TestAction"], equalTo(@"TestConfig"));
  assertThat([subjectInfo configurationNameForAction:@"LaunchAction"], equalTo(@"LaunchConfig"));
  assertThat([subjectInfo configurationNameForAction:@"AnalyzeAction"], equalTo(@"AnalyzeConfig"));
  assertThat([subjectInfo configurationNameForAction:@"ProfileAction"], equalTo(@"ProfileConfig"));
  assertThat([subjectInfo configurationNameForAction:@"ArchiveAction"], equalTo(@"ArchiveConfig"));
}

- (void)testBuildActionPropertiesShouldPopulateFromScheme
{
  XcodeSubjectInfo *subjectInfo =
  [self xcodeSubjectInfoPopulatedWithProject:TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj"
                                      scheme:@"TestProject-Library"];

  assertThatBool(subjectInfo.parallelizeBuildables, isTrue());
  assertThatBool(subjectInfo.buildImplicitDependencies, isTrue());
}

- (void)testShouldTryToFetchBuildSettingsFromMultipleActionsOnXcode5
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    NSArray *handlers = @[[LaunchHandlers handlerForShowBuildSettingsWithAction:@"build"
                                                                        project:TEST_DATA @"ProjectWithOnlyATestTarget/ProjectWithOnlyATestTarget.xcodeproj"
                                                                         scheme:@"ProjectWithOnlyATestTarget"
                                                                   settingsPath:TEST_DATA @"ProjectWithOnlyATestTarget-showBuildSettings-build.txt"
                                                                           hide:NO],
                          [LaunchHandlers handlerForShowBuildSettingsWithAction:@"test"
                                                                        project:TEST_DATA @"ProjectWithOnlyATestTarget/ProjectWithOnlyATestTarget.xcodeproj"
                                                                         scheme:@"ProjectWithOnlyATestTarget"
                                                                   settingsPath:TEST_DATA @"ProjectWithOnlyATestTarget-showBuildSettings-test.txt"
                                                                           hide:NO],
                          ];
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:handlers];

    Options *options = [Options optionsFrom:@[@"-project", TEST_DATA @"ProjectWithOnlyATestTarget/ProjectWithOnlyATestTarget.xcodeproj",
                                              @"-scheme", @"ProjectWithOnlyATestTarget",
                                              ]];

    XcodeSubjectInfo *subjectInfo = [[XcodeSubjectInfo alloc] init];
    [subjectInfo setSubjectProject:[options project]];
    [subjectInfo setSubjectScheme:[options scheme]];
    [subjectInfo setSubjectXcodeBuildArguments:[options xcodeBuildArgumentsForSubject]];

    [subjectInfo loadSubjectInfo];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];

    // Should have called xcodebuild with -showBuildSettings twice!
    assertThatInteger(launchedTasks.count, equalToInteger(2));
    // First with the 'build' action, but that should fail.
    assertThat([launchedTasks[0] arguments],
               containsArray(@[@"build", @"-showBuildSettings"]));
    // Second with the 'test' action, and this should work.
    assertThat([launchedTasks[1] arguments],
               containsArray(@[@"test", @"-showBuildSettings"]));
  }];
}

- (void)testBuildableAndTestableAreCorrectlyReadWhenSchemeReferencesNestedProject
{
  XcodeSubjectInfo *subjectInfo = [[XcodeSubjectInfo alloc] init];
  NSString *schemePath = TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes.xcodeproj/xcshareddata/xcschemes/TestProject-RecursiveProjectsAndSchemes-InternalTests.xcscheme";
  [subjectInfo populateBuildablesAndTestablesForWorkspaceWithSchemePath:schemePath];

  assertThat([subjectInfo.testables valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryATests",
    @"InternalProjectLibraryBTests",
    @"InternalProjectLibraryCTests",
  ]));
  assertThat([subjectInfo.buildables valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryATests",
    @"InternalProjectLibraryBTests",
    @"InternalProjectLibraryCTests",
  ]));
  assertThat([subjectInfo.buildablesForTest valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryATests",
    @"InternalProjectLibraryBTests",
    @"InternalProjectLibraryCTests",
  ]));

  schemePath = TEST_DATA "TestProject-RecursiveProjectsAndSchemes/InternalProjectLibraryA/InternalProjectLibraryA.xcodeproj/xcshareddata/xcschemes/InternalProjectLibraryA.xcscheme";
  [subjectInfo populateBuildablesAndTestablesForWorkspaceWithSchemePath:schemePath];

  assertThat([subjectInfo.testables valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryATests",
  ]));
  assertThat([subjectInfo.buildables valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryA",
    @"InternalProjectLibraryATests",
  ]));
  assertThat([subjectInfo.buildablesForTest valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryA",
    @"InternalProjectLibraryATests",
  ]));

  schemePath = TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes/OtherProjects/InternalProjectLibraryB/InternalProjectLibraryB.xcodeproj/xcshareddata/xcschemes/InternalProjectLibraryB.xcscheme";
  [subjectInfo populateBuildablesAndTestablesForWorkspaceWithSchemePath:schemePath];

  assertThat([subjectInfo.testables valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryBTests",
  ]));
  assertThat([subjectInfo.buildables valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryB",
    @"InternalProjectLibraryBTests",
  ]));
  assertThat([subjectInfo.buildablesForTest valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryB",
    @"InternalProjectLibraryBTests",
  ]));

  schemePath = TEST_DATA "TestProject-RecursiveProjectsAndSchemes/InternalProjectLibraryC/HideProjectFolder/WhyNotMore/InternalProjectLibraryC.xcodeproj/xcshareddata/xcschemes/InternalProjectLibraryC.xcscheme";
  [subjectInfo populateBuildablesAndTestablesForWorkspaceWithSchemePath:schemePath];

  assertThat([subjectInfo.testables valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryCTests",
  ]));
  assertThat([subjectInfo.buildables valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryC",
    @"InternalProjectLibraryCTests",
  ]));
  assertThat([subjectInfo.buildablesForTest valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryC",
    @"InternalProjectLibraryCTests",
  ]));

  schemePath = TEST_DATA "TestProject-RecursiveProjectsAndSchemes/InternalProjectLibraryC/HideProjectFolder/WhyNotMore/InternalProjectLibraryC.xcodeproj/xcshareddata/xcschemes/InternalProjectLibraryTests.xcscheme";
  [subjectInfo populateBuildablesAndTestablesForWorkspaceWithSchemePath:schemePath];

  assertThat([subjectInfo.testables valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryATests",
    @"InternalProjectLibraryBTests",
    @"InternalProjectLibraryCTests",
  ]));
  assertThat([subjectInfo.buildables valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryA",
    @"InternalProjectLibraryB",
    @"InternalProjectLibraryC",
  ]));
  assertThat([subjectInfo.buildablesForTest valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryA",
    @"InternalProjectLibraryB",
    @"InternalProjectLibraryC",
  ]));

  schemePath = TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes.xcworkspace/xcshareddata/xcschemes/WorkspaceInternalProjectLibraryTests.xcscheme";
  [subjectInfo populateBuildablesAndTestablesForWorkspaceWithSchemePath:schemePath];

  assertThat([subjectInfo.testables valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryATests",
    @"InternalProjectLibraryBTests",
    @"InternalProjectLibraryCTests",
  ]));
  assertThat([subjectInfo.buildables valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryA",
    @"InternalProjectLibraryB",
    @"InternalProjectLibraryC",
  ]));
  assertThat([subjectInfo.buildablesForTest valueForKeyPath:@"target"], equalTo(@[
    @"InternalProjectLibraryA",
    @"InternalProjectLibraryB",
    @"InternalProjectLibraryC",
  ]));
}

- (void)testBuildableAndTestableInSchemeAreIgnoredForNonExistingProjects
{
  XcodeSubjectInfo *subjectInfo = [[XcodeSubjectInfo alloc] init];
  NSString *schemePath = TEST_DATA "TestProject-WithNonExistingTargetInScheme/TestProject-WithNonExistingTargetInScheme.xcodeproj/xcshareddata/xcschemes/TestProject-WithNonExistingTargetInScheme.xcscheme";
  [subjectInfo populateBuildablesAndTestablesForWorkspaceWithSchemePath:schemePath];

  assertThat([subjectInfo.testables valueForKeyPath:@"target"], equalTo(@[
    @"TestProject-WithNonExistingTargetInSchemeTests",
  ]));
  assertThat([subjectInfo.buildables valueForKeyPath:@"target"], equalTo(@[
    @"TestProject-WithNonExistingTargetInScheme",
    @"TestProject-WithNonExistingTargetInSchemeTests",
  ]));
  assertThat([subjectInfo.buildablesForTest valueForKeyPath:@"target"], equalTo(@[
    @"TestProject-WithNonExistingTargetInScheme",
    @"TestProject-WithNonExistingTargetInSchemeTests",
  ]));
}

@end
