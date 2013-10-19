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

#import "OCUnitIOSTestQueryRunner.h"

#import "iPhoneSimulatorRemoteClient.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"

NSString *SimulatorSDKRootPathWithVersion(NSString *version)
{
  return [NSString stringWithFormat:@"%@/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator%@.sdk",
          XcodeDeveloperDirPath(),
          version];
}

@implementation OCUnitIOSTestQueryRunner

- (NSString *)sdk
{
  NSString *sdk = _buildSettings[@"SDK_NAME"];
  NSCAssert([sdk hasPrefix:@"iphonesimulator"], @"Only iphonesimulator SDKs are supported.");
  return sdk;
}

- (NSDictionary *)envForQueryInIOSBundleWithAdditionalEnv:(NSDictionary *)additionalEnv
{
  NSString *version = [[self sdk] stringByReplacingOccurrencesOfString:@"iphonesimulator" withString:@""];
  NSString *simulatorHome = [NSString stringWithFormat:@"%@/Library/Application Support/iPhone Simulator/%@", NSHomeDirectory(), version];
  NSString *sdkRootPath = SimulatorSDKRootPathWithVersion(version);

  NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:@{
    @"CFFIXED_USER_HOME" : simulatorHome,
    @"HOME" : simulatorHome,
    @"IPHONE_SHARED_RESOURCES_DIRECTORY" : simulatorHome,
    @"DYLD_ROOT_PATH" : sdkRootPath,
    @"IPHONE_SIMULATOR_ROOT" : sdkRootPath,
    @"NSUnbufferedIO" : @"YES"
  }];
  if (additionalEnv) {
    [env addEntriesFromDictionary:additionalEnv];
  }

  return env;
}

// We need to default to 32-bit for all iOS tests, but shouldn't mess with it
// if it's been explicitly specified already.
- (cpu_type_t)cpuType
{
  if ([super cpuType] == CPU_TYPE_ANY) {
    [super setCpuType:CPU_TYPE_I386];
  }
  return [super cpuType];
}

@end
