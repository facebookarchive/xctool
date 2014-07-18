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

#import "OCUnitOSXAppTestQueryRunner.h"

#import "TaskUtil.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

@implementation OCUnitOSXAppTestQueryRunner

- (NSTask *)createTaskForQuery
{
  NSString *builtProductsDir = _buildSettings[Xcode_BUILT_PRODUCTS_DIR];

  NSTask *task = CreateTaskInSameProcessGroup();
  [task setLaunchPath:[self testHostPath]];
  [task setArguments:@[]];
  [task setEnvironment:@{@"DYLD_INSERT_LIBRARIES" : [XCToolLibPath() stringByAppendingPathComponent:@"otest-query-lib-osx.dylib"],
                         // The test bundle that we want to query from, as loaded by otest-query-lib-osx.dylib.
                         @"OtestQueryBundlePath" : [self bundlePath],
                         @"DYLD_FRAMEWORK_PATH" : builtProductsDir,
                         @"DYLD_LIBRARY_PATH" : builtProductsDir,
                         @"DYLD_FALLBACK_FRAMEWORK_PATH" : OSXTestFrameworkDirectories(),
                         @"NSUnbufferedIO" : @"YES",
                         @"OBJC_DISABLE_GC" : @"YES",
                         @"__CFPREFERENCES_AVOID_DAEMON" : @"YES",
                         }];

  return task;
}

@end
