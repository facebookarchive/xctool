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

#import <Foundation/Foundation.h>

#import <SenTestingKit/SenTestingKit.h>

#import "XCToolUtil.h"
#import "XcodeSubjectInfo.h"
#import "XcodeTargetMatch.h"

@interface XcodeSubjectInfoTests : SenTestCase
@end

@implementation XcodeSubjectInfoTests

- (void)testCanGetProjectPathsInWorkspace
{
  NSArray *paths = [XcodeSubjectInfo projectPathsInWorkspace:TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace"];
  assertThat(paths, equalTo(@[TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj"]));
}

- (void)testCanGetProjectPathsInWorkspaceWhenPathsAreRelativeToGroups
{
  // In contents.xcworkspacedata, FileRefs can have paths relative to the groups they're within.
  NSArray *paths = [XcodeSubjectInfo projectPathsInWorkspace:TEST_DATA @"WorkspacePathTest/NestedDir/SomeWorkspace.xcworkspace"];
  assertThat(paths,
             equalTo(@[
                     TEST_DATA @"WorkspacePathTest/OtherNestedDir/OtherProject/OtherProject.xcodeproj",
                     TEST_DATA @"WorkspacePathTest/NestedDir/SomeProject/SomeProject.xcodeproj"]));
}

- (void)testCanGetAllSchemesInAProject
{
  NSArray *schemes = [XcodeSubjectInfo schemePathsInContainer:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"];
  assertThat(schemes, equalTo(@[TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj/xcshareddata/xcschemes/TestProject-Library.xcscheme"]));
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
  assertThatBool(ret, equalToBool(YES));
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
  assertThatBool(ret, equalToBool(YES));
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

@end
