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

NSArray *OTestQueryTestCasesInIOSBundle(NSString *bundlePath, NSString *sdk)
{
  NSCAssert([sdk hasPrefix:@"iphonesimulator"], @"Only iphonesimulator SDKs are supported.");

  NSString *version = [sdk stringByReplacingOccurrencesOfString:@"iphonesimulator" withString:@""];
  DTiPhoneSimulatorSystemRoot *systemRoot = [DTiPhoneSimulatorSystemRoot rootWithSDKVersion:version];
  NSCAssert(systemRoot != nil, @"Cannot get systemRoot");
  NSString *simulatorHome = [NSString stringWithFormat:@"%@/Library/Application Support/iPhone Simulator/%@", NSHomeDirectory(), version];

  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath:[XCToolLibExecPath() stringByAppendingPathComponent:@"otest-query-ios"]];
  [task setEnvironment:@{@"CFFIXED_USER_HOME" : simulatorHome,
                         @"HOME" : simulatorHome,
                         @"IPHONE_SHARED_RESOURCES_DIRECTORY" : simulatorHome,
                         @"DYLD_ROOT_PATH" : [systemRoot sdkRootPath],
                         @"IPHONE_SIMULATOR_ROOT" : [systemRoot sdkRootPath],
                         @"IPHONE_SIMULATOR_VERSIONS" : @"iPhone Simulator (external launch) , iPhone OS 6.0 (unknown/10A403)",
                         @"NSUnbufferedIO" : @"YES"}];
  [task setArguments:@[bundlePath]];
  NSDictionary *output = LaunchTaskAndCaptureOutput(task);
  NSCAssert([task terminationStatus] == 0, @"otest-query-ios failed with stderr: %@", output[@"stderr"]);
  NSData *outputData = [output[@"stdout"] dataUsingEncoding:NSUTF8StringEncoding];
  [task release];
  return [NSJSONSerialization JSONObjectWithData:outputData options:0 error:nil];
}

NSArray *OTestQueryTestCasesInOSXBundle(NSString *bundlePath, NSString *builtProductsDir, BOOL disableGC)
{
  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath:[XCToolLibExecPath() stringByAppendingPathComponent:@"otest-query-osx"]];
  [task setArguments:@[bundlePath]];
  [task setEnvironment:@{
   @"DYLD_FRAMEWORK_PATH" : builtProductsDir,
   @"DYLD_LIBRARY_PATH" : builtProductsDir,
   @"DYLD_FALLBACK_FRAMEWORK_PATH" : [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/Frameworks"],
   @"NSUnbufferedIO" : @"YES",
   @"OBJC_DISABLE_GC" : disableGC ? @"YES" : @"NO"
   }];
  NSDictionary *output = LaunchTaskAndCaptureOutput(task);
  NSCAssert([task terminationStatus] == 0, @"otest-query-ios failed with stderr: %@", output[@"stderr"]);
  [task release];
  NSData *outputData = [output[@"stdout"] dataUsingEncoding:NSUTF8StringEncoding];
  return [NSJSONSerialization JSONObjectWithData:outputData options:0 error:nil];
}
