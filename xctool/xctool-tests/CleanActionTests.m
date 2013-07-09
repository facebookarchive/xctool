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

#import <SenTestingKit/SenTestingKit.h>

#import "Action.h"
#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "LaunchHandlers.h"
#import "Options.h"
#import "RunTestsAction.h"
#import "SchemeGenerator.h"
#import "Swizzler.h"
#import "TaskUtil.h"
#import "TestUtil.h"
#import "XCTool.h"
#import "XCToolUtil.h"
#import "xcodeSubjectInfo.h"

@interface CleanActionTests : SenTestCase
@end

@implementation CleanActionTests

- (void)setUp
{
  [super setUp];
}

- (void)testCleanActionTriggersCleanForProjectAndSchemeAndTests
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj"
                                                     scheme:@"TestProject-Library"
                                               settingsPath:TEST_DATA @"TestProject-Library-showBuildSettings.txt"],
     ]];

    NSString *mockWorkspacePath = @"/tmp/nowhere/Tests.xcworkspace";
    id mockSchemeGenerator = mock([SchemeGenerator class]);
    [given([mockSchemeGenerator writeWorkspaceNamed:@"Tests"])
     willReturn:mockWorkspacePath];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"clean",
                       ];

    [Swizzler whileSwizzlingSelector:@selector(schemeGenerator)
                            forClass:[SchemeGenerator class]
                           withBlock:^(Class c, SEL sel){ return mockSchemeGenerator; }
                            runBlock:^{ [TestUtil runWithFakeStreams:tool]; }];

    NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([launchedTasks count], equalToInteger(2));
    assertThat([launchedTasks[0] arguments],
               equalTo(@[
                       @"-project", TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"Debug",
                       @"clean",
                       ]));
    assertThat([launchedTasks[1] arguments],
               equalTo(@[
                       @"-configuration", @"Debug",
                       @"-workspace", mockWorkspacePath,
                       @"-scheme", @"Tests",
                       @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates",
                       @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-amxcwsnetnrvhrdeikqmcczcgmwn/Build/Intermediates/PrecompiledHeaders",
                       [NSString stringWithFormat:@"-IDECustomDerivedDataLocation=%@xctool_temp_UNDERTEST/DerivedData", NSTemporaryDirectory()],
                       @"clean",
                       ]));
  }];
}

- (void)testConfigurationIsTakenFromScheme
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     // Make sure -showBuildSettings returns some data
     [LaunchHandlers handlerForShowBuildSettingsWithProject:TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj"
                                                     scheme:@"TestProject-Library"
                                               settingsPath:TEST_DATA @"TestProject-Library-WithDifferentConfigurations-showBuildSettings.txt"],
     ]];

    XCTool *tool = [[[XCTool alloc] init] autorelease];

    tool.arguments = @[@"-project", TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"clean",
                       ];

    [TestUtil runWithFakeStreams:tool];

    NSArray *tasks = [[FakeTaskManager sharedManager] launchedTasks];
    assertThatInteger([tasks count], equalToInteger(2));
    assertThat([tasks[0] arguments],
               equalTo(@[
                       @"-project", TEST_DATA @"TestProject-Library-WithDifferentConfigurations/TestProject-Library.xcodeproj",
                       @"-scheme", @"TestProject-Library",
                       @"-configuration", @"LaunchConfig",
                       @"clean",
                       ]));
    assertThat(ArgumentListByOverriding([tasks[1] arguments],
                                        @"-workspace",
                                        @"/path/to/Tests.xcworkspace"),
               equalTo(@[
                       @"-configuration",
                       @"TestConfig",
                       @"-workspace",
                       @"/path/to/Tests.xcworkspace",
                       @"-scheme",
                       @"Tests",
                       @"OBJROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-dcmgtqlclwxdzqevoakcspwlrpfm/Build/Intermediates",
                       @"SYMROOT=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-dcmgtqlclwxdzqevoakcspwlrpfm/Build/Products",
                       @"SHARED_PRECOMPS_DIR=/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-dcmgtqlclwxdzqevoakcspwlrpfm/Build/Intermediates/PrecompiledHeaders",
                       [NSString stringWithFormat:@"-IDECustomDerivedDataLocation=%@xctool_temp_UNDERTEST/DerivedData", NSTemporaryDirectory()],
                       @"clean"
                       ]));
  }];
}

@end
