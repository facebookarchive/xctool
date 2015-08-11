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

#import "OCUnitIOSLogicTestRunner.h"

#import "NSConcreteTask.h"
#import "SimDevice.h"
#import "SimulatorInfo.h"
#import "TaskUtil.h"
#import "TestingFramework.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

static NSString * const XCTOOL_CFFIXED_USER_HOME = @"CFFIXED_USER_HOME";
static NSString * const XCTOOL_HOME = @"HOME";
static NSString * const XCTOOL_TMPDIR = @"TMPDIR";

@implementation OCUnitIOSLogicTestRunner

- (NSTask *)otestTaskWithTestBundle:(NSString *)testBundlePath
{
  NSString *launchPath = [NSString pathWithComponents:@[
    _buildSettings[Xcode_SDKROOT],
    @"Developer",
    _framework[kTestingFrameworkIOSTestrunnerName],
  ]];

  NSArray *args = nil;
  NSMutableDictionary *env = [NSMutableDictionary dictionary];
  if (ToolchainIsXcode7OrBetter()) {
    args = [self commonTestArguments];
    env = [[self testEnvironmentWithSpecifiedTestConfiguration] mutableCopy];
  } else {
    args = [[self testArgumentsWithSpecifiedTestsToRun] arrayByAddingObject:testBundlePath];
  }

  // In Xcode 6 `sim` doesn't set `CFFIXED_USER_HOME` if simulator is not launched
  // but this environment is used, for example, by NSHomeDirectory().
  // Let's pass that environment along with `HOME` and `TMPDIR`.
  SimDevice *device = [_simulatorInfo simulatedDevice];
  NSDictionary *deviceEnvironment = [device environment];
  NSString *deviceDataPath = [device dataPath];
  if (deviceEnvironment[XCTOOL_CFFIXED_USER_HOME]) {
    env[XCTOOL_CFFIXED_USER_HOME] = deviceEnvironment[XCTOOL_CFFIXED_USER_HOME];
  } else if (deviceDataPath) {
    env[XCTOOL_CFFIXED_USER_HOME] = deviceDataPath;
  }
  if (deviceEnvironment[XCTOOL_HOME]) {
    env[XCTOOL_HOME] = deviceEnvironment[XCTOOL_HOME];
  } else if (deviceDataPath) {
    env[XCTOOL_HOME] = deviceDataPath;
  }
  if (deviceEnvironment[XCTOOL_TMPDIR]) {
    env[XCTOOL_TMPDIR] = deviceEnvironment[XCTOOL_TMPDIR];
  } else if (deviceDataPath) {
    env[XCTOOL_TMPDIR] = [NSString pathWithComponents:@[deviceDataPath, @"tmp"]];
  }

  // adding custom xctool environment variables
  [env addEntriesFromDictionary:IOSTestEnvironment(_buildSettings)];
  [env addEntriesFromDictionary:@{
    @"DYLD_INSERT_LIBRARIES" : [XCToolLibPath() stringByAppendingPathComponent:@"otest-shim-ios.dylib"],
    @"NSUnbufferedIO" : @"YES",
  }];

  // and merging with process environments and `_environment` variable contents
  env = [self otestEnvironmentWithOverrides:env];

  return CreateTaskForSimulatorExecutable(_buildSettings[Xcode_SDK_NAME],
                                          _simulatorInfo,
                                          launchPath,
                                          args,
                                          env);
}

- (void)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock
                   startupError:(NSString **)startupError
                    otherErrors:(NSString **)otherErrors
{
  NSString *testBundlePath = [_simulatorInfo productBundlePath];
  BOOL bundleExists = [[NSFileManager defaultManager] fileExistsAtPath:testBundlePath];

  if (IsRunningUnderTest()) {
    // If we're running under test, pretend the bundle exists even if it doesn't.
    bundleExists = YES;
  }

  if (bundleExists) {
    NSString *output = nil;
    @autoreleasepool {
      NSPipe *outputPipe = [NSPipe pipe];

      NSTask *task = [self otestTaskWithTestBundle:testBundlePath];

      // Don't let STDERR pass through.  This silences the warning message that
      // comes from the 'sim' launcher when the iOS Simulator isn't running:
      // "Simulator does not seem to be running, or may be running an old SDK."
      [task setStandardError:outputPipe];

      NSMutableData *outputData = [[NSMutableData alloc] init];

      dispatch_io_t io = dispatch_io_create(DISPATCH_IO_STREAM, outputPipe.fileHandleForReading.fileDescriptor, dispatch_get_main_queue(), NULL);
      dispatch_io_read(io, 0, SIZE_MAX, dispatch_get_main_queue(), ^(bool done, dispatch_data_t data, int error) {
        if (data) {
          dispatch_data_apply(data, ^bool(dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
            [outputData appendBytes:buffer length:size];
            return true;
          });
        }
      });

      LaunchTaskAndFeedOuputLinesToBlock(task,
                                         @"running otest/xctest on test bundle",
                                         outputLineBlock);

      dispatch_io_close(io, DISPATCH_IO_STOP);
      dispatch_release(io);

      output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
    }
    *otherErrors = output;
  } else {
    *startupError = [NSString stringWithFormat:@"Test bundle not found at: %@", testBundlePath];
  }
}

@end
