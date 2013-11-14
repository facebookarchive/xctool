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

#import "OCUnitOSXLogicTestQueryRunner.h"

#import "iPhoneSimulatorRemoteClient.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"

@implementation OCUnitOSXLogicTestQueryRunner

- (NSTask *)createTaskForQuery
{
  NSString *builtProductsDir = _buildSettings[@"BUILT_PRODUCTS_DIR"];

  BOOL disableGC = YES;
  NSString *gccEnableObjcGC = _buildSettings[@"GCC_ENABLE_OBJC_GC"];
  if ([gccEnableObjcGC isEqualToString:@"required"] ||
      [gccEnableObjcGC isEqualToString:@"supported"]) {
    disableGC = NO;
  }

  NSTask *task = CreateTaskInSameProcessGroup();

  [task setLaunchPath:[XCToolLibExecPath() stringByAppendingPathComponent:@"otest-query-osx"]];
  [task setArguments:@[ [self bundlePath] ]];
  [task setEnvironment:@{
    @"DYLD_FRAMEWORK_PATH" : builtProductsDir,
    @"DYLD_LIBRARY_PATH" : builtProductsDir,
    @"DYLD_FALLBACK_FRAMEWORK_PATH" : [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/Frameworks"],
    @"NSUnbufferedIO" : @"YES",
    @"OBJC_DISABLE_GC" : disableGC ? @"YES" : @"NO"
  }];

  return task;
}


@end
