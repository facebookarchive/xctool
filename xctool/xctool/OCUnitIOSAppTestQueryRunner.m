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

#import "OCUnitIOSAppTestQueryRunner.h"

#import "TaskUtil.h"
#import "XCToolUtil.h"

@implementation OCUnitIOSAppTestQueryRunner

- (NSTask *)createTaskForQuery
{
  NSTask *task;
  task = CreateTaskInSameProcessGroupWithArch([self cpuType]);
  NSString *bundlePath = [self bundlePath];
  NSString *testHostPath = [self testHostPath];

  [task setLaunchPath:testHostPath];
  [task setArguments:@[ bundlePath ]];

  [task setEnvironment:[self envForQueryInIOSBundleWithAdditionalEnv:@{
    // Inserted this dylib, which will then load whatever is in `OtestQueryBundlePath`.
    @"DYLD_INSERT_LIBRARIES" : [XCToolLibPath() stringByAppendingPathComponent:@"otest-query-ios-dylib.dylib"],
    // The test bundle that we want to query from.
    @"OtestQueryBundlePath" : bundlePath,
  }]];
  return task;
}

@end