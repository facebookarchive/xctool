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
  OSXInsertSanitizerLibrariesIfNeeded(environment, [_simulatorInfo productBundlePath]);

  NSString *taskLaunchPath = nil;
  NSMutableArray *taskArguments = [NSMutableArray array];
  NSString *otestQueryExecutablePath = [XCToolLibExecPath() stringByAppendingPathComponent:@"otest-query-osx"];

  // force to run otest-query executable in i386 mode if
  // it is the only supported architecture by the project
  NSString *archs = _simulatorInfo.buildSettings[@"ARCHS"];
  if ([archs isEqualToString:@"i386"]) {
    // when running `arch`, pass all environment variables
    // via "-e" option
    taskLaunchPath = @"/usr/bin/arch";
    [taskArguments addObject:@"-i386"];
    for (NSString *key in environment) {
      [taskArguments addObject:@"-e"];
      [taskArguments addObject:[NSString stringWithFormat:@"%@=%@", key, environment[key]]];
    }
    // reset environment
    environment = [NSMutableDictionary dictionary];
    // and finally pass executable to launch
    [taskArguments addObject:otestQueryExecutablePath];
  } else {
    taskLaunchPath = otestQueryExecutablePath;
  }
  // specify test bundle to query
  [taskArguments addObject:[_simulatorInfo productBundlePath]];

  NSTask *task = CreateTaskInSameProcessGroup();
  [task setLaunchPath:taskLaunchPath];
  [task setArguments:taskArguments];
  [task setEnvironment:environment];

  return task;
}


@end
