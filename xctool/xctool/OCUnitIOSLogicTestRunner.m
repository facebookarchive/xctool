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
#import "OTestQuery.h"
#import "TaskUtil.h"
#import "TestingFramework.h"
#import "XCToolUtil.h"

@implementation OCUnitIOSLogicTestRunner

- (NSDictionary *)environmentOverrides
{
  NSString *version = [_buildSettings[@"SDK_NAME"] stringByReplacingOccurrencesOfString:@"iphonesimulator" withString:@""];
  NSString *simulatorHome = [NSString stringWithFormat:@"%@/Library/Application Support/iPhone Simulator/%@", NSHomeDirectory(), version];

  return @{@"CFFIXED_USER_HOME" : simulatorHome,
           @"HOME" : simulatorHome,
           @"IPHONE_SHARED_RESOURCES_DIRECTORY" : simulatorHome,
           @"DYLD_FALLBACK_FRAMEWORK_PATH" : @"/Developer/Library/Frameworks",
           @"DYLD_FRAMEWORK_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
           @"DYLD_LIBRARY_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
           @"DYLD_ROOT_PATH" : _buildSettings[@"SDKROOT"],
           @"IPHONE_SIMULATOR_ROOT" : _buildSettings[@"SDKROOT"],
           @"IPHONE_SIMULATOR_VERSIONS" : @"iPhone Simulator (external launch) , iPhone OS 6.0 (unknown/10A403)",
           @"NSUnbufferedIO" : @"YES"};
}

- (NSTask *)otestTaskWithTestBundle:(NSString *)testBundlePath
{
  NSConcreteTask *task = (NSConcreteTask *)[[[NSTask alloc] init] autorelease];

  // As of the Xcode 5 GM, the iPhoneSimulator version of 'otest' is now a
  // universal binary.  By default, the x86_64 version will be run. That's a
  // problem because 1) Xcode doesn't build iPhoneSimulator tests as x86_64 by
  // default (yet), and 2) otest-shim + otest-query are still i386 only.
  //
  // Let's force otest to start as i386 for now.
  //
  // At some point Apple may introduce universal binaries for iOS simulator
  // apps.  When that happens, we'll need to make otest-shim-ios a fat binary
  // and run tests twice - once against i386 and x86_64 - which is how Xcode
  // handles testing for universal OS X binaries.
  [task setPreferredArchitectures:@[@(CPU_TYPE_I386)]];

  [task setLaunchPath:[NSString stringWithFormat:@"%@/Developer/%@", _buildSettings[@"SDKROOT"], _framework[kTestingFrameworkIOSTestrunnerName]]];
  [task setArguments:[[self testArguments] arrayByAddingObject:testBundlePath]];
  NSMutableDictionary *env = [[self.environmentOverrides mutableCopy] autorelease];
  env[@"DYLD_INSERT_LIBRARIES"] = [XCToolLibPath() stringByAppendingPathComponent:@"otest-shim-ios.dylib"];
  [task setEnvironment:[self otestEnvironmentWithOverrides:env]];
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
      LaunchTaskAndFeedOuputLinesToBlock(task, outputLineBlock);
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
