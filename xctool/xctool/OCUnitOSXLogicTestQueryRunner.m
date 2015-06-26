//
// Copyright 2004-present Facebook. All Rights Reserved.
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

#import "SimulatorInfo.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

@implementation OCUnitOSXLogicTestQueryRunner

- (void)prepareToRunQuery
{
  // otest-query defaults are cleared to ensure that when the task created below
  // is launched `NSUserDefaults` won't have unexpected values.
  NSTask *cleanTask = CreateTaskInSameProcessGroup();
  [cleanTask setLaunchPath:@"/usr/bin/defaults"];
  [cleanTask setArguments:@[@"delete", @"otest-query-osx"]];
  [cleanTask setStandardError:[NSFileHandle fileHandleWithNullDevice]];
  [cleanTask launch];
  [cleanTask waitUntilExit];
}

- (NSTask *)createTaskForQuery
{
  NSMutableDictionary *environment = OSXTestEnvironment(_simulatorInfo.buildSettings);
  [environment addEntriesFromDictionary:@{
    // Specifying `NSArgumentDomain` forces XCTest/SenTestingKit frameworks to use values
    // of otest-query-osx `NSUserDefaults` which are changed in otest-query to manipulate
    // mentioned frameworks behaviour.
    @"NSArgumentDomain" : @"otest-query-osx",
    @"OBJC_DISABLE_GC" : @"YES",
    @"__CFPREFERENCES_AVOID_DAEMON" : @"YES",
  }];

  NSTask *task = CreateTaskInSameProcessGroup();
  [task setLaunchPath:[XCToolLibExecPath() stringByAppendingPathComponent:@"otest-query-osx"]];
  [task setArguments:@[ [_simulatorInfo productBundlePath] ]];
  [task setEnvironment:environment];

  return task;
}


@end
