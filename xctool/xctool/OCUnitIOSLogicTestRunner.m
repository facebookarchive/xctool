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

#import "OCUnitIOSLogicTestRunner.h"

#import "NSConcreteTask.h"
#import "TaskUtil.h"
#import "TestingFramework.h"
#import "XCToolUtil.h"

@implementation OCUnitIOSLogicTestRunner

- (NSTask *)otestTaskWithTestBundle:(NSString *)testBundlePath
{
  NSString *version = [_buildSettings[@"SDK_NAME"] stringByReplacingOccurrencesOfString:@"iphonesimulator" withString:@""];

  NSTask *task = [CreateTaskInSameProcessGroup() autorelease];
  [task setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Platforms/iPhoneSimulator.platform/usr/bin/sim"]];

  NSMutableArray *args = [NSMutableArray array];
  [args addObjectsFromArray:@[[@"--arch=" stringByAppendingString:([self cpuType] == CPU_TYPE_X86_64) ? @"64" : @"32"],
                              [@"--sdk=" stringByAppendingString:version],
                              @"--environment=merge",
                              [NSString stringWithFormat:@"%@/Developer/%@", _buildSettings[@"SDKROOT"], _framework[kTestingFrameworkIOSTestrunnerName]],
                              ]];
  [args addObjectsFromArray:[self testArguments]];
  [args addObject:testBundlePath];
  
  [task setArguments:args];
  [task setEnvironment:[self otestEnvironmentWithOverrides:
                        @{
                          // sim-shim.dylib let's us insert extra environment variables into the launched
                          // process (via the SIMSHIM_*) vars.
                          @"DYLD_INSERT_LIBRARIES" : [XCToolLibPath() stringByAppendingPathComponent:@"sim-shim.dylib"],
                          // Insert into the process launched by sim.
                          @"SIMSHIM_DYLD_INSERT_LIBRARIES" : [XCToolLibPath() stringByAppendingPathComponent:@"otest-shim-ios.dylib"],
                          @"SIMSHIM_DYLD_FRAMEWORK_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
                          @"SIMSHIM_DYLD_LIBRARY_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
                          @"NSUnbufferedIO" : @"YES",
                          }]];
  return task;
}

- (BOOL)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock
              gotUncaughtSignal:(BOOL *)gotUncaughtSignal
                          error:(NSString **)error
{
  NSString *sdkName = _buildSettings[@"SDK_NAME"];
  NSAssert([sdkName hasPrefix:@"iphonesimulator"], @"Unexpected SDK name: %@", sdkName);

  NSString *testBundlePath = [self testBundlePath];
  BOOL bundleExists = [[NSFileManager defaultManager] fileExistsAtPath:testBundlePath];

  if (IsRunningUnderTest()) {
    // If we're running under test, pretend the bundle exists even if it doesn't.
    bundleExists = YES;
  }

  if (bundleExists) {
    @autoreleasepool {
      NSTask *task = [self otestTaskWithTestBundle:testBundlePath];

      // Don't let STDERR pass through.  This silences the warning message that
      // comes from the 'sim' launcher when the iOS Simulator isn't running:
      // "Simulator does not seem to be running, or may be running an old SDK."
      [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];

      LaunchTaskAndFeedOuputLinesToBlock(task,
                                         @"running otest/xctest on test bundle",
                                         outputLineBlock);
      *gotUncaughtSignal = task.terminationReason == NSTaskTerminationReasonUncaughtSignal;

      return [task terminationStatus] == 0 ? YES : NO;
    }
  } else {
    *error = [NSString stringWithFormat:@"Test bundle not found at: %@", testBundlePath];
    *gotUncaughtSignal = NO;
    return NO;
  }
}

@end
