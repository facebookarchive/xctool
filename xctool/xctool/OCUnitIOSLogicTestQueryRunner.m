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

#import "OCUnitIOSLogicTestQueryRunner.h"

#import "TaskUtil.h"
#import "XCToolUtil.h"

@implementation OCUnitIOSLogicTestQueryRunner

- (NSTask *)createTaskForQuery
{
  NSTask *task = CreateTaskInSameProcessGroupWithArch([self cpuType]);
  [task setLaunchPath:[XCToolLibExecPath() stringByAppendingPathComponent:@"otest-query-ios"]];
  [task setEnvironment:[self envForQueryInIOSBundleWithAdditionalEnv:nil]];
  [task setArguments:@[ [self bundlePath] ]];
  return task;
}

@end