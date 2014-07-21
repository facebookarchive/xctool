//
// Copyright 2014 Facebook
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

#import "SimulatorInfo.h"

#import "SimulatorInfoXcode5.h"
#import "SimulatorInfoXcode6.h"
#import "XcodeBuildSettings.h"
#import "XCToolUtil.h"

@implementation SimulatorInfo

+ (Class)classBasedOnCurrentVersionOfXcode
{
  if (ToolchainIsXcode6OrBetter()) {
    return [SimulatorInfoXcode6 class];
  } else {
    return [SimulatorInfoXcode5 class];
  }
}

+ (SimulatorInfo *)infoForCurrentVersionOfXcode
{
  return [[[self classBasedOnCurrentVersionOfXcode] alloc] init];
}

#pragma mark -
#pragma mark Redirect to available class

+ (NSArray *)availableDevices
{
  return [[self classBasedOnCurrentVersionOfXcode] availableDevices];
}

+ (NSString *)deviceNameForAlias:(NSString *)deviceAlias
{
  return [[self classBasedOnCurrentVersionOfXcode] deviceNameForAlias:deviceAlias];
}

+ (BOOL)isDeviceAvailableWithAlias:(NSString *)deviceName
{
  return [[self classBasedOnCurrentVersionOfXcode] isDeviceAvailableWithAlias:deviceName];
}

+ (BOOL)isSdkVersion:(NSString *)sdkVersion supportedByDevice:(NSString *)deviceName
{
  return [[self classBasedOnCurrentVersionOfXcode] isSdkVersion:sdkVersion supportedByDevice:deviceName];
}

+ (NSString *)sdkVersionForOSVersion:(NSString *)osVersion
{
  return [[self classBasedOnCurrentVersionOfXcode] sdkVersionForOSVersion:osVersion];
}

+ (NSArray *)availableSdkVersions
{
  return [[self classBasedOnCurrentVersionOfXcode] availableSdkVersions];
}

+ (NSArray *)sdksSupportedByDevice:(NSString *)deviceName
{
  return [[self classBasedOnCurrentVersionOfXcode] sdksSupportedByDevice:deviceName];
}

+ (cpu_type_t)cpuTypeForDevice:(NSString *)deviceName
{
  return [[self classBasedOnCurrentVersionOfXcode] cpuTypeForDevice:deviceName];
}

+ (NSString *)baseVersionForSDKShortVersion:(NSString *)shortVersionString
{
  return [[self classBasedOnCurrentVersionOfXcode] baseVersionForSDKShortVersion:shortVersionString];
}

#pragma mark -
#pragma mark Common


- (NSDictionary *)simulatorLaunchEnvironment
{
  // Sometimes the TEST_HOST will be wrapped in double quotes.
  NSString *testHostPath = [_buildSettings[Xcode_TEST_HOST] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];

  NSString *ideBundleInjectionLibPath = @"/../../Library/PrivateFrameworks/IDEBundleInjection.framework/IDEBundleInjection";
  NSString *testBundlePath = [NSString stringWithFormat:@"%@/%@", _buildSettings[Xcode_BUILT_PRODUCTS_DIR], _buildSettings[Xcode_FULL_PRODUCT_NAME]];

  return @{
    @"DYLD_FALLBACK_FRAMEWORK_PATH" : IOSTestFrameworkDirectories(),
    @"DYLD_FRAMEWORK_PATH" : _buildSettings[Xcode_TARGET_BUILD_DIR],
    @"DYLD_LIBRARY_PATH" : _buildSettings[Xcode_TARGET_BUILD_DIR],
    @"DYLD_INSERT_LIBRARIES" : [@[
      [XCToolLibPath() stringByAppendingPathComponent:@"otest-shim-ios.dylib"],
      ideBundleInjectionLibPath,
     ] componentsJoinedByString:@":"],
    @"NSUnbufferedIO" : @"YES",
    @"XCInjectBundle" : testBundlePath,
    @"XCInjectBundleInto" : testHostPath,
    };
}

#pragma mark -
#pragma mark Should be implemented in subclass

- (NSString *)simulatedArchitecture {assert(NO);};
- (NSNumber *)simulatedDeviceFamily {assert(NO);};
- (NSString *)simulatedDeviceInfoName {assert(NO);};
- (NSString *)simulatedSdkVersion {assert(NO);};
- (NSString *)simulatedSdkShortVersion {assert(NO);};
- (NSString *)simulatedSdkRootPath {assert(NO);};
- (NSNumber *)launchTimeout {assert(NO);};
- (DTiPhoneSimulatorSystemRoot *)systemRootForSimulatedSdk{assert(NO);};

@end
