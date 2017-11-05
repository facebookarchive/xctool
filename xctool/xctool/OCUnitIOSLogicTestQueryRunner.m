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

#import "OCUnitIOSLogicTestQueryRunner.h"

#import "SimulatorInfo.h"
#import "SimulatorTaskUtils.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

static NSString * const DYLD_INSERT_LIBRARIES = @"DYLD_INSERT_LIBRARIES";

@implementation OCUnitIOSLogicTestQueryRunner

- (NSTask *)createTaskForQuery
{
  NSMutableDictionary *environment = nil;
  NSString *launchPath = nil;
  NSString *sdkName = _simulatorInfo.buildSettings[Xcode_SDK_NAME];
  if ([sdkName hasPrefix:@"iphonesimulator"]) {
    environment = IOSTestEnvironment(_simulatorInfo.buildSettings);
    environment[DYLD_INSERT_LIBRARIES] = [XCToolLibPath() stringByAppendingPathComponent:@"otest-query-lib-ios.dylib"];
    IOSInsertSanitizerLibrariesIfNeeded(environment, [_simulatorInfo productBundlePath]);
    launchPath = [XCToolLibExecPath() stringByAppendingPathComponent:@"otest-query-ios"];
  } else if ([sdkName hasPrefix:@"appletvsimulator"]) {
    environment = TVOSTestEnvironment(_simulatorInfo.buildSettings);
    environment[DYLD_INSERT_LIBRARIES] = [XCToolLibPath() stringByAppendingPathComponent:@"otest-query-lib-appletv.dylib"];
    TVOSInsertSanitizerLibrariesIfNeeded(environment, [_simulatorInfo productBundlePath]);
    launchPath = [XCToolLibExecPath() stringByAppendingPathComponent:@"otest-query-appletv"];
  } else {
    NSAssert(false, @"'%@' sdk is not yet supported", sdkName);
  }
  [environment addEntriesFromDictionary:@{
    // The test bundle that we want to query from, as loaded by otest-query-lib-ios.dylib.
    @"OtestQueryBundlePath" : [_simulatorInfo productBundlePath],
    @"__CFPREFERENCES_AVOID_DAEMON" : @"YES",
  }];

  return CreateTaskForSimulatorExecutable(
    _simulatorInfo.buildSettings[Xcode_SDK_NAME],
    _simulatorInfo,
    launchPath,
    @[],
    environment
  );
}

@end
