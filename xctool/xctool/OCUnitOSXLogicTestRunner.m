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


#import "OCUnitOSXLogicTestRunner.h"

#import "TaskUtil.h"
#import "TestingFramework.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

static NSString * const DYLD_INSERT_LIBRARIES = @"DYLD_INSERT_LIBRARIES";

@implementation OCUnitOSXLogicTestRunner

- (NSMutableDictionary *)environmentOverrides
{
  NSMutableDictionary *environment = OSXTestEnvironment(_buildSettings);
  [environment addEntriesFromDictionary:@{
    @"OBJC_DISABLE_GC" : !_garbageCollection ? @"YES" : @"NO",
  }];
  return environment;
}

- (NSTask *)otestTaskWithTestBundle:(NSString *)testBundlePath otestShimOutputPath:(NSString **)otestShimOutputPath
{
  NSTask *task = CreateTaskInSameProcessGroup();

  // For OSX test bundles only, Xcode will chdir to the project's directory.
  NSString *projectDir = _buildSettings[Xcode_PROJECT_DIR];
  if (projectDir) {
    [task setCurrentDirectoryPath:projectDir];
  }

  NSMutableArray *args = [@[] mutableCopy];
  NSMutableDictionary *env = [self environmentOverrides];
  if (ToolchainIsXcode7OrBetter()) {
    [args addObjectsFromArray:[self commonTestArguments]];
    [env addEntriesFromDictionary:[self testEnvironmentWithSpecifiedTestConfiguration]];
  } else {
    [args addObjectsFromArray:[self testArgumentsWithSpecifiedTestsToRun]];
    [args addObject:testBundlePath];
  }

  env[DYLD_INSERT_LIBRARIES] = [XCToolLibPath() stringByAppendingPathComponent:@"otest-shim-osx.dylib"];
  OSXInsertSanitizerLibrariesIfNeeded(env, [_simulatorInfo productBundlePath]);

  // specify a path where to write otest-shim events
  NSString *outputPath = MakeTempFileWithPrefix(@"output");
  [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
  env[@"OTEST_SHIM_STDOUT_FILE"] = outputPath;
  env = [self otestEnvironmentWithOverrides:env];
  *otestShimOutputPath = outputPath;

  NSString *launchPath = nil;
  NSString *xctestPath = [XcodeDeveloperDirPath() stringByAppendingPathComponent:_framework[kTestingFrameworkOSXTestrunnerName]];

  // force to run xctest executable in i386 mode if
  // it is the only supported architecture by the project
  NSString *archs = _simulatorInfo.buildSettings[@"ARCHS"];
  if ([archs isEqualToString:@"i386"]) {
    // when running `arch`, pass all environment variables
    // via "-e" option
    launchPath = @"/usr/bin/arch";
    NSUInteger nextIndexPath = 0;
    [args insertObject:@"-i386" atIndex:nextIndexPath++];
    for (NSString *key in env) {
      [args insertObject:@"-e" atIndex:nextIndexPath++];
      [args insertObject:[NSString stringWithFormat:@"%@=%@", key, env[key]]
                 atIndex:nextIndexPath++];
    }
    // reset environment
    env = [NSMutableDictionary dictionary];
    // and finally pass executable to launch
    [args insertObject:xctestPath atIndex:nextIndexPath++];
  } else {
    launchPath = xctestPath;
  }

  [task setLaunchPath:launchPath];
  [task setArguments:args];
  [task setEnvironment:env];
  return task;
}

- (void)runTestsAndFeedOutputTo:(FdOutputLineFeedBlock)outputLineBlock
                   startupError:(NSString **)startupError
                    otherErrors:(NSString **)otherErrors
{
  NSAssert([_buildSettings[Xcode_SDK_NAME] hasPrefix:@"macosx"], @"Should be a macosx SDK.");

  NSString *testBundlePath = [_simulatorInfo productBundlePath];
  BOOL bundleExists = [[NSFileManager defaultManager] fileExistsAtPath:testBundlePath];

  if (IsRunningUnderTest()) {
    // If we're running under test, pretend the bundle exists even if it doesn't.
    bundleExists = YES;
  }

  if (bundleExists) {
    @autoreleasepool {
      NSString *otestShimOutputPath = nil;
      NSTask *task = [self otestTaskWithTestBundle:testBundlePath otestShimOutputPath:&otestShimOutputPath];
      LaunchTaskAndFeedSimulatorOutputAndOtestShimEventsToBlock(
        task,
        @"running otest/xctest on test bundle",
        otestShimOutputPath,
        outputLineBlock);
    }
  } else {
    *startupError = [NSString stringWithFormat:@"Test bundle not found at: %@", testBundlePath];
  }
}

@end
