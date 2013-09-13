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

#import "OTestQuery.h"

#import "iPhoneSimulatorRemoteClient.h"

#import "TaskUtil.h"
#import "XCToolUtil.h"

static NSString *SimulatorSDKRootPathWithVersion(NSString *version)
{
  return [NSString stringWithFormat:@"%@/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator%@.sdk",
          XcodeDeveloperDirPath(),
          version];
}

static NSArray *RunTaskAndReturnResult(NSTask *task, NSString **error)
{
  NSDictionary *output = LaunchTaskAndCaptureOutput(task);

  if ([task terminationStatus] != 0) {
    *error = output[@"stderr"];
    return nil;
  } else {
    NSString *jsonOutput = output[@"stdout"];

    NSError *parseError = nil;
    NSArray *list = [NSJSONSerialization JSONObjectWithData:[jsonOutput dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      error:&parseError];
    if (list) {
      return list;
    } else {
      *error = [NSString stringWithFormat:@"Error while parsing JSON: %@: %@",
                [parseError localizedFailureReason],
                jsonOutput];
      return nil;
    }
  }
}

static BOOL SetErrorIfBundleDoesNotExist(NSString *bundlePath, NSString **error)
{
  BOOL isDir = NO;
  BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:bundlePath isDirectory:&isDir];

  if (!IsRunningUnderTest() && !(exists && isDir)) {
    *error = [NSString stringWithFormat:@"Test bundle not found at: %@", bundlePath];
    return YES;
  } else {
    return NO;
  }
}

NSArray *OTestQueryTestCasesInIOSBundle(NSString *bundlePath, NSString *sdk, NSString **error)
{
  NSCAssert([sdk hasPrefix:@"iphonesimulator"], @"Only iphonesimulator SDKs are supported.");

  if (SetErrorIfBundleDoesNotExist(bundlePath, error)) {
    return nil;
  }

  NSString *version = [sdk stringByReplacingOccurrencesOfString:@"iphonesimulator" withString:@""];
  NSString *simulatorHome = [NSString stringWithFormat:@"%@/Library/Application Support/iPhone Simulator/%@", NSHomeDirectory(), version];
  NSString *sdkRootPath = SimulatorSDKRootPathWithVersion(version);

  NSTask *task = CreateTaskInSameProcessGroup();
  [task setLaunchPath:[XCToolLibExecPath() stringByAppendingPathComponent:@"otest-query-ios"]];
  [task setEnvironment:@{@"CFFIXED_USER_HOME" : simulatorHome,
                         @"HOME" : simulatorHome,
                         @"IPHONE_SHARED_RESOURCES_DIRECTORY" : simulatorHome,
                         @"DYLD_ROOT_PATH" : sdkRootPath,
                         @"IPHONE_SIMULATOR_ROOT" : sdkRootPath,
                         @"IPHONE_SIMULATOR_VERSIONS" : @"iPhone Simulator (external launch) , iPhone OS 6.0 (unknown/10A403)",
                         @"NSUnbufferedIO" : @"YES"}];
  [task setArguments:@[bundlePath]];

  NSArray *result = RunTaskAndReturnResult(task, error);
  [task release];
  return result;
}

NSArray *OTestQueryTestCasesInIOSBundleWithTestHost(NSString *bundlePath, NSString *testHostExecutablePath, NSString *sdk, NSString **error)
{
  NSCAssert([sdk hasPrefix:@"iphonesimulator"], @"Only iphonesimulator SDKs are supported.");

  if (SetErrorIfBundleDoesNotExist(bundlePath, error)) {
    return nil;
  }

  if (![[NSFileManager defaultManager] isExecutableFileAtPath:testHostExecutablePath]) {
    *error = [NSString stringWithFormat:@"The test host executable is missing: '%@'", testHostExecutablePath];
    return nil;
  }

  NSString *version = [sdk stringByReplacingOccurrencesOfString:@"iphonesimulator" withString:@""];
  NSString *simulatorHome = [NSString stringWithFormat:@"%@/Library/Application Support/iPhone Simulator/%@", NSHomeDirectory(), version];
  NSString *sdkRootPath = SimulatorSDKRootPathWithVersion(version);

  NSTask *task = CreateTaskInSameProcessGroup();
  [task setLaunchPath:testHostExecutablePath];
  [task setEnvironment:@{
   // Inserted this dylib, which will then load whatever is in `OtestQueryBundlePath`.
   @"DYLD_INSERT_LIBRARIES" : [XCToolLibPath() stringByAppendingPathComponent:@"otest-query-ios-dylib.dylib"],
   // The test bundle that we want to query from.
   @"OtestQueryBundlePath" : bundlePath,

   @"CFFIXED_USER_HOME" : simulatorHome,
   @"HOME" : simulatorHome,
   @"IPHONE_SHARED_RESOURCES_DIRECTORY" : simulatorHome,
   @"DYLD_ROOT_PATH" : sdkRootPath,
   @"IPHONE_SIMULATOR_ROOT" : sdkRootPath,
   @"IPHONE_SIMULATOR_VERSIONS" : @"iPhone Simulator (external launch) , iPhone OS 6.0 (unknown/10A403)",
   @"NSUnbufferedIO" : @"YES"}];
  [task setArguments:@[bundlePath]];

  NSArray *result = RunTaskAndReturnResult(task, error);
  [task release];
  return result;
}

NSArray *OTestQueryTestCasesInOSXBundle(NSString *bundlePath, NSString *builtProductsDir, BOOL disableGC, NSString **error)
{
  if (SetErrorIfBundleDoesNotExist(bundlePath, error)) {
    return nil;
  }

  NSTask *task = CreateTaskInSameProcessGroup();
  [task setLaunchPath:[XCToolLibExecPath() stringByAppendingPathComponent:@"otest-query-osx"]];
  [task setArguments:@[bundlePath]];
  [task setEnvironment:@{
   @"DYLD_FRAMEWORK_PATH" : builtProductsDir,
   @"DYLD_LIBRARY_PATH" : builtProductsDir,
   @"DYLD_FALLBACK_FRAMEWORK_PATH" : [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/Frameworks"],
   @"NSUnbufferedIO" : @"YES",
   @"OBJC_DISABLE_GC" : disableGC ? @"YES" : @"NO"
   }];

  NSArray *result = RunTaskAndReturnResult(task, error);
  [task release];
  return result;
}
