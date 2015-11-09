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

#import "OCUnitOSXAppTestRunner.h"

#import "ReportStatus.h"
#import "TaskUtil.h"
#import "TestingFramework.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

@implementation OCUnitOSXAppTestRunner

- (void)runTestsAndFeedOutputTo:(FdOutputLineFeedBlock)outputLineBlock
                   startupError:(NSString **)startupError
                    otherErrors:(NSString **)otherErrors
{
  NSString *sdkName = _buildSettings[Xcode_SDK_NAME];
  NSAssert([sdkName hasPrefix:@"macosx"], @"Unexpected SDK: %@", sdkName);

  if (![[NSFileManager defaultManager] isExecutableFileAtPath:[_simulatorInfo testHostPath]]) {
    // It's conceivable that isExecutableFileAtPath is wrong; for example, maybe we're on
    // a wonky FS, or running as root, or running with differing real/effective UIDs.
    // Unfortunately, there's no way to be sure without actually running TEST_HOST, and
    // NSTask throws an exception if the execve fails, and that's a nasty failure mode for
    // us. It's better to fail usefully for obviously wrong TEST_HOSTs than support
    // incredibly odd configs.
    ReportStatusMessage(_reporters, REPORTER_MESSAGE_ERROR,
                        @"Your TEST_HOST '%@' does not appear to be an executable.", [_simulatorInfo testHostPath]);
    *startupError = @"TEST_HOST not executable.";
    return;
  }

  NSMutableDictionary *environment = [_simulatorInfo simulatorLaunchEnvironment];
  [environment addEntriesFromDictionary:@{
    @"OBJC_DISABLE_GC" : !_garbageCollection ? @"YES" : @"NO",
  }];

  NSArray *args = nil;
  if (ToolchainIsXcode7OrBetter()) {
    args = [self commonTestArguments];
    [environment addEntriesFromDictionary:[self testEnvironmentWithSpecifiedTestConfiguration]];
  } else {
    args = [self testArgumentsWithSpecifiedTestsToRun];
  }

  // specify a path where to write otest-shim events
  NSString *outputPath = MakeTempFileWithPrefix(@"output");
  [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
  environment[@"OTEST_SHIM_STDOUT_FILE"] = outputPath;

  NSTask *task = CreateTaskInSameProcessGroup();
  [task setLaunchPath:[_simulatorInfo testHostPath]];
  [task setArguments:args];
  [task setEnvironment:[self otestEnvironmentWithOverrides:environment]];
  // For OSX test bundles only, Xcode will chdir to the project's directory.
  NSString *projectDir = _buildSettings[Xcode_PROJECT_DIR];
  if (projectDir) {
    [task setCurrentDirectoryPath:projectDir];
  }

  NSString *otestShimOutputPath = outputPath;
  LaunchTaskAndFeedSimulatorOutputAndOtestShimEventsToBlock(
    task,
    @"running otest/xctest on test bundle",
    otestShimOutputPath,
    outputLineBlock);
}

@end
