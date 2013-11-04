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
  NSString *version = [_buildSettings[@"SDK_NAME"] stringByReplacingOccurrencesOfString:@"iphonesimulator" withString:@""];

  NSTask *task = CreateTaskInSameProcessGroup();
  [task setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Platforms/iPhoneSimulator.platform/usr/bin/sim"]];
  [task setArguments:@[[@"--arch=" stringByAppendingString:([self cpuType] == CPU_TYPE_X86_64) ? @"64" : @"32"],
                       [@"--sdk=" stringByAppendingString:version],
                       @"--environment=merge",
                       [self testHostPath],
                       ]];
  [task setEnvironment:@{// We insert a shim into the 'sim' process so that we can
                         // add some extra environment variables to otest-query-ios as it's launched.
                         @"DYLD_INSERT_LIBRARIES" : [XCToolLibPath() stringByAppendingPathComponent:@"sim-shim.dylib"],
                         // sim-sim will launched the spawned process with this value for DYLD_INSERT_LIBRARIES.
                         @"SIMSHIM_DYLD_INSERT_LIBRARIES" : [XCToolLibPath() stringByAppendingPathComponent:@"otest-query-ios-dylib.dylib"],
                         // The test bundle that we want to query from, as loaded by otest-query-ios-dylib.
                         @"OtestQueryBundlePath" : [self bundlePath],
                         }];
  return task;
}

@end