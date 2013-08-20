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


#import "OCUnitOSXLogicTestRunner.h"

#import "OTestQuery.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"

@implementation OCUnitOSXLogicTestRunner

- (NSDictionary *)environmentOverrides
{
  return @{@"DYLD_FRAMEWORK_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
           @"DYLD_LIBRARY_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
           @"DYLD_FALLBACK_FRAMEWORK_PATH" : [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/Frameworks"],
           @"NSUnbufferedIO" : @"YES",
           @"OBJC_DISABLE_GC" : !_garbageCollection ? @"YES" : @"NO",
           };
}

- (NSTask *)otestTaskWithTestBundle:(NSString *)testBundlePath
{
  NSTask *task = [[[NSTask alloc] init] autorelease];
  [task setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Tools/otest"]];
  // When invoking otest directly, the last arg needs to be the the test bundle.
  [task setArguments:[[self otestArguments] arrayByAddingObject:testBundlePath]];
  NSMutableDictionary *env = [[self.environmentOverrides mutableCopy] autorelease];
  env[@"DYLD_INSERT_LIBRARIES"] = [XCToolLibPath() stringByAppendingPathComponent:@"otest-shim-osx.dylib"];
  [task setEnvironment:[self otestEnvironmentWithOverrides:env]];
  return task;
}

- (BOOL)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock
              gotUncaughtSignal:(BOOL*)gotUncaughtSignal
                          error:(NSString **)error
{
  NSAssert([_buildSettings[@"SDK_NAME"] hasPrefix:@"macosx"], @"Should be a macosx SDK.");

  NSString *testBundlePath = [self testBundlePath];
  BOOL bundleExists = [[NSFileManager defaultManager] fileExistsAtPath:testBundlePath];

  if (IsRunningUnderTest()) {
    // If we're running under test, pretend the bundle exists even if it doesn't.
    bundleExists = YES;
  }

  if (bundleExists) {
    @autoreleasepool {
      NSTask *task = [self otestTaskWithTestBundle:testBundlePath];
      // For OSX test bundles only, Xcode will chdir to the project's directory.
      [task setCurrentDirectoryPath:_buildSettings[@"PROJECT_DIR"]];

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
