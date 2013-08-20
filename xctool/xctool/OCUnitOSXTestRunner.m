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

#import "OCUnitOSXTestRunner.h"

#import "TaskUtil.h"
#import "XCToolUtil.h"

@implementation OCUnitOSXTestRunner

- (NSDictionary *)environmentOverrides
{
  return @{@"DYLD_FRAMEWORK_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
           @"DYLD_LIBRARY_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
           @"DYLD_FALLBACK_FRAMEWORK_PATH" : [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/Frameworks"],
           @"NSUnbufferedIO" : @"YES",
           @"OBJC_DISABLE_GC" : !_garbageCollection ? @"YES" : @"NO",
           };
}

- (NSArray *)runTestClassListQuery
{
  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath:[XCToolLibExecPath() stringByAppendingPathComponent:@"otest-query-osx"]];
  [task setArguments:@[self.testBundlePath]];
  [task setEnvironment:[self otestEnvironmentWithOverrides:self.environmentOverrides]];
  NSDictionary *output = LaunchTaskAndCaptureOutput(task);
  [task release];
  NSData *outputData = [output[@"stdout"] dataUsingEncoding:NSUTF8StringEncoding];
  return [NSJSONSerialization JSONObjectWithData:outputData options:0 error:nil];
}

@end
