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
#import "OCUnitIOSTestRunner.h"

#import "TaskUtil.h"
#import "XCToolUtil.h"

@implementation OCUnitIOSTestRunner

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

- (NSArray *)runTestClassListQuery
{
  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath:[XCToolLibExecPath() stringByAppendingPathComponent:@"otest-query-ios"]];
  [task setArguments:@[self.testBundlePath]];
  [task setEnvironment:[self otestEnvironmentWithOverrides:self.environmentOverrides]];
  NSDictionary *output = LaunchTaskAndCaptureOutput(task);
  NSData *outputData = [output[@"stdout"] dataUsingEncoding:NSUTF8StringEncoding];
  [task release];
  return [NSJSONSerialization JSONObjectWithData:outputData options:0 error:nil];
}

@end
