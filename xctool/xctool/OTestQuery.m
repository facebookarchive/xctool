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

#import "TaskUtil.h"
#import "XCToolUtil.h"

NSArray *OTestQueryTestClassesInIOSBundle(NSString *bundlePath, NSString *sdk)
{
  NSCAssert([sdk hasPrefix:@"iphonesimulator"], @"Only iphonesimulator SDKs are supported.");
  
  NSTask *task = [[NSTask alloc] init];
  // 'sim' is a nice wrapper that takes care of launch simulator binaries in the
  // correct environment.
  [task setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"/Platforms/iPhoneSimulator.platform/usr/bin/sim"]];
  [task setArguments:@[
   [NSString stringWithFormat:@"--sdk=%@", [sdk stringByReplacingOccurrencesOfString:@"iphonesimulator" withString:@""]],
   @"--environment=discard",
   [XCToolLibExecPath() stringByAppendingPathComponent:@"otest-query-ios"],
   bundlePath,
   ]];
  [task setEnvironment:@{@"PATH": SystemPaths()}];
  NSDictionary *output = LaunchTaskAndCaptureOutput(task);
  NSCAssert([task terminationStatus] == 0, @"otest-query-ios failed with stderr: %@", output[@"stderr"]);
  NSData *outputData = [output[@"stdout"] dataUsingEncoding:NSUTF8StringEncoding];
  [task release];
  return [NSJSONSerialization JSONObjectWithData:outputData options:0 error:nil];
}

NSArray *OTestQueryTestClassesInOSXBundle(NSString *bundlePath, NSString *builtProductsDir, BOOL disableGC)
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
