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

#import <XCTest/XCTest.h>

#import "Action.h"
#import "BuildTestsAction.h"
#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "LaunchHandlers.h"
#import "Options+Testing.h"
#import "Options.h"
#import "SchemeGenerator.h"
#import "Swizzler.h"
#import "TaskUtil.h"
#import "TestUtil.h"
#import "XCTool.h"
#import "XCToolUtil.h"
#import "xcodeSubjectInfo.h"

static NSString *kTestProjectTestProjectLibraryTargetID         = @"2828291F16B11F0F00426B92";
static NSString *kTestProjectTestProjectLibraryTestTargetID     = @"2828293016B11F0F00426B92";
static NSString *kTestWorkspaceTestProjectLibraryTargetID       = @"28A33CCF16CF03EA00C5EE2A";
static NSString *kTestWorkspaceTestProjectLibraryTestsTargetID  = @"28A33CE016CF03EA00C5EE2A";
static NSString *kTestWorkspaceTestProjectLibraryTests2TargetID = @"28ADB42416E40E23006301ED";
static NSString *kTestWorkspaceTestProjectOtherLibTargetID      = @"28ADB45F16E42E9A006301ED";

@interface BuildTestsActionTests : XCTestCase
@end

@implementation BuildTestsActionTests

- (void)testOnlyListAndOmitListCannotBothBeSpecified
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  [[Options optionsFrom:@[
    @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
    @"-scheme", @"TestProject-Library",
    @"-sdk", @"iphonesimulator6.1",
    @"build-tests",
    @"-only", @"TestProject-LibraryTests",
    @"-omit", @"TestProject-LibraryTests",
    ]]
   assertOptionsFailToValidateWithError:
   @"build-tests: -only and -omit cannot both be specified."
   withBuildSettingsFromFile:
   TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
   ];
}

- (void)testOnlyListIsCollected
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator6.1",
                       @"build-tests", @"-only", @"TestProject-LibraryTests",
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  BuildTestsAction *action = options.actions[0];
  assertThat((action.onlyList), equalTo(@[@"TestProject-LibraryTests"]));
}

- (void)testOmitListIsCollected
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator6.1",
                       @"build-tests", @"-omit", @"TestProject-LibraryTests",
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  BuildTestsAction *action = options.actions[0];
  assertThat((action.omitList), equalTo(@[@"TestProject-LibraryTests"]));
}

- (void)testSkipDependenciesIsCollected
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  Options *options = [[Options optionsFrom:@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-sdk", @"iphonesimulator6.1",
                       @"build-tests", @"-only", @"TestProject-LibraryTests",
                       @"-skip-deps"
                       ]] assertOptionsValidateWithBuildSettingsFromFile:
                      TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
                      ];
  BuildTestsAction *action = options.actions[0];
  assertThatBool(action.skipDependencies, isTrue());
}

- (void)testOnlyListRequiresValidTarget
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  [[Options optionsFrom:@[
    @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
    @"-scheme", @"TestProject-Library",
    @"-sdk", @"iphonesimulator6.1",
    @"build-tests", @"-only", @"BOGUS_TARGET",
    ]]
   assertOptionsFailToValidateWithError:
   @"build-tests: 'BOGUS_TARGET' is not a testing target in this scheme."
   withBuildSettingsFromFile:
   TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"
   ];
}

- (void)testBuildTestsAction
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    NSString *projectPath = TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj";

    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:projectPath
                                                     scheme:@"TestProject-Library"
                                               settingsPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"],
     ]];

    NSString *mockWorkspacePath = @"/tmp/nowhere/Tests.xcworkspace";
    id mockSchemeGenerator = mock([SchemeGenerator class]);
    [given([mockSchemeGenerator writeWorkspaceNamed:@"Tests"])
     willReturn:mockWorkspacePath];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[
                       @"-project", projectPath,
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"build-tests",
                       @"-reporter", @"plain",
                       ];

    [Swizzler whileSwizzlingSelector:@selector(schemeGenerator)
                            forClass:[SchemeGenerator class]
                           withBlock:^(Class c, SEL sel){ return mockSchemeGenerator; }
                            runBlock:^{ [TestUtil runWithFakeStreams:tool]; }];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(1));
    assertThat([launchedTasks[0] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"PLATFORM_NAME=iphonesimulator",
                       @"-workspace", mockWorkspacePath,
                       @"-scheme", @"Tests",
                       @"OBJROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Intermediates",
                       @"SYMROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Intermediates/PrecompiledHeaders",
                       [NSString stringWithFormat:@"-IDECustomDerivedDataLocation=%@xctool_temp_UNDERTEST_%d/DerivedData", NSTemporaryDirectory(), [[NSProcessInfo processInfo] processIdentifier]],
                       @"build",
                       ]));
    assertThatInt(tool.exitStatus, equalToInt(0));

    [verify(mockSchemeGenerator) setParallelizeBuildables:YES];
    [verify(mockSchemeGenerator) setBuildImplicitDependencies:YES];
    [verify(mockSchemeGenerator) addProjectPathToWorkspace:projectPath];
    [verify(mockSchemeGenerator) addBuildableWithID:kTestProjectTestProjectLibraryTargetID
                                          inProject:projectPath];
    [verify(mockSchemeGenerator) addBuildableWithID:kTestProjectTestProjectLibraryTestTargetID
                                          inProject:projectPath];
    [verify(mockSchemeGenerator) writeWorkspaceNamed:@"Tests"];
  }];
}

- (void)testBuildTestsActionWillBuildEverythingMarkedAsBuildForTest
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithWorkspace:TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace"
                                                       scheme:@"TestProject-Library"
                                                 settingsPath:TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"],
     ]];

    NSString *mockWorkspacePath = @"/tmp/nowhere/Tests.xcworkspace";
    id mockSchemeGenerator = mock([SchemeGenerator class]);
    [given([mockSchemeGenerator writeWorkspaceNamed:@"Tests"])
     willReturn:mockWorkspacePath];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[
                       @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"build-tests",
                       @"-reporter", @"plain",
                       ];

    [Swizzler whileSwizzlingSelector:@selector(schemeGenerator)
                            forClass:[SchemeGenerator class]
                           withBlock:^(Class c, SEL sel){ return mockSchemeGenerator; }
                            runBlock:^{ [TestUtil runWithFakeStreams:tool]; }];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(1));
    assertThat([launchedTasks[0] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"PLATFORM_NAME=iphonesimulator",
                       @"-workspace", mockWorkspacePath,
                       @"-scheme", @"Tests",
                       @"OBJROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-asazjpviwiufbaajaofbmyqmmghn/Build/Intermediates",
                       @"SYMROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-asazjpviwiufbaajaofbmyqmmghn/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/nekto/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-asazjpviwiufbaajaofbmyqmmghn/Build/Intermediates/PrecompiledHeaders",
                       [NSString stringWithFormat:@"-IDECustomDerivedDataLocation=%@xctool_temp_UNDERTEST_%d/DerivedData", NSTemporaryDirectory(), [[NSProcessInfo processInfo] processIdentifier]],
                       @"build",
                       ]));
    assertThatInt(tool.exitStatus, equalToInt(0));

    NSString *projectPath = TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj";
    [verify(mockSchemeGenerator) setParallelizeBuildables:NO];
    [verify(mockSchemeGenerator) setBuildImplicitDependencies:YES];
    [verify(mockSchemeGenerator) addProjectPathToWorkspace:projectPath];
    [verify(mockSchemeGenerator) addBuildableWithID:kTestWorkspaceTestProjectLibraryTargetID
                                          inProject:projectPath];
    [verify(mockSchemeGenerator) addBuildableWithID:kTestWorkspaceTestProjectOtherLibTargetID
                                          inProject:projectPath];
    [verify(mockSchemeGenerator) addBuildableWithID:kTestWorkspaceTestProjectLibraryTestsTargetID
                                          inProject:projectPath];
    [verify(mockSchemeGenerator) addBuildableWithID:kTestWorkspaceTestProjectLibraryTests2TargetID
                                          inProject:projectPath];
    [verify(mockSchemeGenerator) writeWorkspaceNamed:@"Tests"];
  }];
}

- (void)testBuildTestsCanBuildASingleTarget
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  // In TestWorkspace-Library, we have a target TestProject-LibraryTest2 that depends on
  // TestProject-OtherLib, but it isn't marked as an explicit dependency.  The only way that
  // dependency gets built is that it's added to the scheme as build-for-test above
  // TestProject-LibraryTest2.  This a lame way to setup dependencies (they should be explicit),
  // but we're seeing this in the wild and should support it.
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithWorkspace:TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace"
                                                       scheme:@"TestProject-Library"
                                                 settingsPath:TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"],
     ]];

    NSString *mockWorkspacePath = @"/tmp/nowhere/Tests.xcworkspace";
    id mockSchemeGenerator = mock([SchemeGenerator class]);
    [given([mockSchemeGenerator writeWorkspaceNamed:@"Tests"])
     willReturn:mockWorkspacePath];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[
                       @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"build-tests", @"-only", @"TestProject-LibraryTests",
                       @"-reporter", @"plain",
                       ];

    [Swizzler whileSwizzlingSelector:@selector(schemeGenerator)
                            forClass:[SchemeGenerator class]
                           withBlock:^(Class c, SEL sel){ return mockSchemeGenerator; }
                            runBlock:^{ [TestUtil runWithFakeStreams:tool]; }];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(1));
    assertThat([launchedTasks[0] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"PLATFORM_NAME=iphonesimulator",
                       @"-workspace", mockWorkspacePath,
                       @"-scheme", @"Tests",
                       @"OBJROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-asazjpviwiufbaajaofbmyqmmghn/Build/Intermediates",
                       @"SYMROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-asazjpviwiufbaajaofbmyqmmghn/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/nekto/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-asazjpviwiufbaajaofbmyqmmghn/Build/Intermediates/PrecompiledHeaders",
                       [NSString stringWithFormat:@"-IDECustomDerivedDataLocation=%@xctool_temp_UNDERTEST_%d/DerivedData", NSTemporaryDirectory(), [[NSProcessInfo processInfo] processIdentifier]],
                       @"build",
                       ]));
    assertThatInt(tool.exitStatus, equalToInt(0));

    NSString *projectPath = TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj";
    [verify(mockSchemeGenerator) setParallelizeBuildables:NO];
    [verify(mockSchemeGenerator) setBuildImplicitDependencies:YES];
    [verify(mockSchemeGenerator) addProjectPathToWorkspace:projectPath];
    [verify(mockSchemeGenerator) addBuildableWithID:kTestWorkspaceTestProjectLibraryTargetID
                                          inProject:projectPath];
    [verify(mockSchemeGenerator) addBuildableWithID:kTestWorkspaceTestProjectOtherLibTargetID
                                          inProject:projectPath];
    [verify(mockSchemeGenerator) addBuildableWithID:kTestWorkspaceTestProjectLibraryTestsTargetID
                                          inProject:projectPath];
    [verifyCount(mockSchemeGenerator, times(3)) addBuildableWithID:(id)anything() inProject:(id)anything()];
    [verify(mockSchemeGenerator) writeWorkspaceNamed:@"Tests"];
  }];
}


- (void)testSkipDependencies
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithWorkspace:TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace"
                                                       scheme:@"TestProject-Library"
                                                 settingsPath:TEST_DATA @"TestWorkspace-Library-TestProject-Library-showBuildSettings.txt"],
     ]];

    NSString *mockWorkspacePath = @"/tmp/nowhere/Tests.xcworkspace";
    id mockSchemeGenerator = mock([SchemeGenerator class]);
    [given([mockSchemeGenerator writeWorkspaceNamed:@"Tests"])
     willReturn:mockWorkspacePath];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[
                       @"-workspace", TEST_DATA @"TestWorkspace-Library/TestWorkspace-Library.xcworkspace",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"build-tests",
                       @"-only", @"TestProject-LibraryTests",
                       @"-skip-deps",
                       @"-reporter", @"plain",
                       ];

    [Swizzler whileSwizzlingSelector:@selector(schemeGenerator)
                            forClass:[SchemeGenerator class]
                           withBlock:^(Class c, SEL sel){ return mockSchemeGenerator; }
                            runBlock:^{ [TestUtil runWithFakeStreams:tool]; }];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(1));
    assertThat([launchedTasks[0] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-sdk", @"iphonesimulator6.0",
                       @"PLATFORM_NAME=iphonesimulator",
                       @"-workspace", mockWorkspacePath,
                       @"-scheme", @"Tests",
                       @"OBJROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-asazjpviwiufbaajaofbmyqmmghn/Build/Intermediates",
                       @"SYMROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-asazjpviwiufbaajaofbmyqmmghn/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/nekto/Library/Developer/Xcode/DerivedData/TestWorkspace-Library-asazjpviwiufbaajaofbmyqmmghn/Build/Intermediates/PrecompiledHeaders",
                       [NSString stringWithFormat:@"-IDECustomDerivedDataLocation=%@xctool_temp_UNDERTEST_%d/DerivedData", NSTemporaryDirectory(), [[NSProcessInfo processInfo] processIdentifier]],
                       @"build",
                       ]));
    assertThatInt(tool.exitStatus, equalToInt(0));

    NSString *projectPath = TEST_DATA @"TestWorkspace-Library/TestProject-Library/TestProject-Library.xcodeproj";
    [verify(mockSchemeGenerator) setParallelizeBuildables:NO];
    [verify(mockSchemeGenerator) setBuildImplicitDependencies:YES];
    [verify(mockSchemeGenerator) addProjectPathToWorkspace:projectPath];
    [verify(mockSchemeGenerator) addBuildableWithID:kTestWorkspaceTestProjectLibraryTestsTargetID
                                          inProject:projectPath];
    [verifyCount(mockSchemeGenerator, times(1)) addBuildableWithID:(id)anything() inProject:(id)anything()];
    [verify(mockSchemeGenerator) writeWorkspaceNamed:@"Tests"];
  }];
}

- (void)testConfigurationIsTakenFromScheme
{
  if (ToolchainIsXcode8OrBetter()) {
    PrintTestNotRelevantNotice();
    return;
  }

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj"
                                                     scheme:@"TestProject-Library"
                                               settingsPath:TEST_DATA @"TestProject-Library-TestProject-Library-showBuildSettings.txt"],
     ]];

    XCTool *tool = [[XCTool alloc] init];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"build-tests",
                       @"-reporter", @"plain",
                       ];

    [TestUtil runWithFakeStreams:tool];

    NSArray *xcodebuildArguments = [[[FakeTaskManager sharedManager] launchedTasks][0] arguments];

    // -workspace would normally point to a random path, so we fake this out
    // for testing.
    xcodebuildArguments = ArgumentListByOverriding(xcodebuildArguments,
                                                   @"-workspace",
                                                   @"/fake/path/to/Tests.xcworkspace");

    assertThat(xcodebuildArguments,
               equalTo(@[
                       @"-configuration",
                       @"TestConfig",
                       @"-workspace",
                       @"/fake/path/to/Tests.xcworkspace",
                       @"-scheme",
                       @"Tests",
                       @"OBJROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Intermediates",
                       @"SYMROOT=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/nekto/Library/Developer/Xcode/DerivedData/TestProject-Library-frruszglismbfoceinskphldzhci/Build/Intermediates/PrecompiledHeaders",
                       [NSString stringWithFormat:@"-IDECustomDerivedDataLocation=%@xctool_temp_UNDERTEST_%d/DerivedData", NSTemporaryDirectory(), [[NSProcessInfo processInfo] processIdentifier]],
                       @"build"
                       ]));
  }];
}

@end
