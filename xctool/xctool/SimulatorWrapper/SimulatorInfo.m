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

#import "DTiPhoneSimulatorRemoteClient.h"
#import "ISHDeviceInfo.h"
#import "ISHDeviceVersions.h"
#import "ISHSDKInfo.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

static const NSInteger KProductTypeIphone = 1;
static const NSInteger KProductTypeIpad = 2;

@implementation SimulatorInfo

#pragma mark -
#pragma mark Private methods

+ (ISHSDKInfo *)sdkInfoForShortVersion:(NSString *)sdkVersion
{
  ISHDeviceVersions *versions = [ISHDeviceVersions sharedInstance];
  for (ISHSDKInfo *sdkInfo in [versions allSDKs]) {
    if ([[sdkInfo shortVersionString] isEqualToString:sdkVersion]) {
      return sdkInfo;
    }
  }
  return nil;
}

- (NSString *)sdkVersion
{
  if (self.OSVersion) {
    if ([self.OSVersion isEqualTo:@"latest"]) {
      return [[[ISHDeviceVersions sharedInstance] sdkFromSDKRoot:[[ISHDeviceVersions sharedInstance] latestSDKRoot]] shortVersionString];
    } else {
      return _OSVersion;
    }
  } else {
    ISHSDKInfo *sdkInfo = [[ISHDeviceVersions sharedInstance] sdkFromSDKRoot:_buildSettings[Xcode_SDKROOT]];
    return [sdkInfo shortVersionString];
  }
}

- (NSString *)maxSdkVersionForSimulatedDevice
{
  ISHDeviceVersions *versions = [ISHDeviceVersions sharedInstance];
  ISHDeviceInfo *deviceInfo = [versions deviceInfoNamed:[self simulatedDeviceInfoName]];
  ISHSDKInfo *maxSdk = nil;
  for (ISHSDKInfo *sdkInfo in [versions allSDKs]) {
    if (![deviceInfo supportsSDK:sdkInfo]) {
      continue;
    }
    if ([sdkInfo version] > [maxSdk version]) {
      maxSdk = sdkInfo;
    }
  }
  return [maxSdk shortVersionString];
}

#pragma mark -
#pragma mark Public methods

- (NSNumber *)simulatedDeviceFamily
{
  return @([_buildSettings[Xcode_TARGETED_DEVICE_FAMILY] integerValue]);
}

- (NSString *)simulatedDeviceInfoName
{
  if (_deviceName) {
    return _deviceName;
  }

  NSString *probableDeviceName;
  switch ([[self simulatedDeviceFamily] integerValue]) {
    case KProductTypeIphone:
      probableDeviceName = @"iPhone";
      break;

    case KProductTypeIpad:
      probableDeviceName = @"iPad";
      break;
  }

  ISHSDKInfo *sdkInfo = [SimulatorInfo sdkInfoForShortVersion:[self sdkVersion]];
  if (!sdkInfo) {
    return probableDeviceName;
  }

  ISHDeviceVersions *versions = [ISHDeviceVersions sharedInstance];
  ISHDeviceInfo *deviceInfo = [versions deviceInfoNamed:probableDeviceName];
  while (deviceInfo && ![deviceInfo supportsSDK:sdkInfo]) {
    deviceInfo = [deviceInfo newerEquivalent];
    probableDeviceName = [deviceInfo displayName];
  }

  return probableDeviceName;
}

- (NSString *)simulatedArchitecture
{
  switch (self.cpuType) {
    case CPU_TYPE_I386:
      return @"i386";

    case CPU_TYPE_X86_64:
      return @"x86_64";
  }
  return @"i386";
}

- (NSString *)simulatedSdkVersion
{
  if (self.OSVersion) {
    return [self sdkVersion];
  } else {
    return [self maxSdkVersionForSimulatedDevice];
  }
}

- (NSString *)simulatedSdkRootPath
{
  return [[self systemRootForSimulatedSdk] sdkRootPath];
}

- (NSString *)simulatedSdkShortVersion
{
  ISHSDKInfo *sdkInfo = [[ISHDeviceVersions sharedInstance] sdkFromSDKRoot:[self simulatedSdkRootPath]];
  return [sdkInfo shortVersionString];
}

- (DTiPhoneSimulatorSystemRoot *)systemRootForSimulatedSdk
{
  NSString *sdkVersion = [self simulatedSdkVersion];
  DTiPhoneSimulatorSystemRoot *systemRoot = [DTiPhoneSimulatorSystemRoot rootWithSDKVersion:sdkVersion];
  if (systemRoot) {
    return systemRoot;
  }

  ISHSDKInfo *sdkInfo = [SimulatorInfo sdkInfoForShortVersion:sdkVersion];
  systemRoot = [DTiPhoneSimulatorSystemRoot rootWithSDKPath:[sdkInfo root]];
  if (!systemRoot) {
    NSArray *availableSdks = [[[ISHDeviceVersions sharedInstance] allSDKs] valueForKeyPath:@"shortVersionString"];
    NSAssert(systemRoot != nil, @"Unable to instantiate DTiPhoneSimulatorSystemRoot for sdk version: %@. Available sdks: %@", sdkVersion, availableSdks);
  }
  return systemRoot;
}

- (NSDictionary *)simulatorLaunchEnvironment
{
  // Sometimes the TEST_HOST will be wrapped in double quotes.
  NSString *testHostPath = [_buildSettings[Xcode_TEST_HOST] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];

  NSString *ideBundleInjectionLibPath = @"/../../Library/PrivateFrameworks/IDEBundleInjection.framework/IDEBundleInjection";
  NSString *testBundlePath = [NSString stringWithFormat:@"%@/%@", _buildSettings[Xcode_BUILT_PRODUCTS_DIR], _buildSettings[Xcode_FULL_PRODUCT_NAME]];

  return @{
    @"DYLD_FALLBACK_FRAMEWORK_PATH" : [[self simulatedSdkRootPath] stringByAppendingPathComponent:@"/Developer/Library/Frameworks"],
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
#pragma mark Class Methods

+ (NSArray *)availableDevices
{
  return [[ISHDeviceVersions sharedInstance] allDeviceNames];
}

+ (BOOL)isDeviceAvailableWithAlias:(NSString *)deviceName
{
  return [[ISHDeviceVersions sharedInstance] deviceInfoNamed:deviceName] != nil;
}

+ (ISHSDKInfo *)sdkWithVersion:(NSString *)sdkVersion
{
  __block ISHSDKInfo *sdkInfo = nil;
  [[[ISHDeviceVersions sharedInstance] allSDKs] enumerateObjectsUsingBlock:^(ISHSDKInfo *currentSdkInfo, NSUInteger idx, BOOL *stop) {
    if ([[currentSdkInfo shortVersionString] hasPrefix:sdkVersion]) {
      sdkInfo = currentSdkInfo;
      *stop = YES;
    }
  }];
  return sdkInfo;
}

+ (BOOL)isSdkVersion:(NSString *)sdkVersion supportedByDevice:(NSString *)deviceName
{
  ISHDeviceInfo *deviceInfo = [[ISHDeviceVersions sharedInstance] deviceInfoNamed:deviceName];
  ISHSDKInfo *sdkInfo = [self sdkWithVersion:sdkVersion];
  return [deviceInfo supportsSDK:sdkInfo];
}

+ (NSString *)sdkVersionForOSVersion:(NSString *)osVersion
{
  ISHSDKInfo *sdkInfo = nil;
  if ([osVersion isEqualToString:@"latest"]) {
    sdkInfo = [[ISHDeviceVersions sharedInstance] sdkFromSDKRoot:[[ISHDeviceVersions sharedInstance] latestSDKRoot]];
  } else {
    sdkInfo = [self sdkWithVersion:osVersion];
  }
  return [sdkInfo shortVersionString];
}

+ (NSArray *)availableSdkVersions
{
  return [[[ISHDeviceVersions sharedInstance] allSDKs] valueForKeyPath:@"shortVersionString"];
}

+ (NSArray *)sdksSupportedByDevice:(NSString *)deviceName
{
  ISHDeviceInfo *deviceInfo = [[ISHDeviceVersions sharedInstance] deviceInfoNamed:deviceName];
  NSMutableArray *supportedSdks = [NSMutableArray array];
  for (ISHSDKInfo *sdk in [[ISHDeviceVersions sharedInstance] allSDKs]) {
    if ([deviceInfo supportsSDK:sdk]) {
      [supportedSdks addObject:sdk];
    }
  }
  return supportedSdks;
}

+ (cpu_type_t)cpuTypeForDevice:(NSString *)deviceName
{
  ISHDeviceInfo *deviceInfo = [[ISHDeviceVersions sharedInstance] deviceInfoNamed:deviceName];
  if ([[deviceInfo architecture] isEqualToString:@"x86_64"]) {
    return CPU_TYPE_X86_64;
  } else {
    return CPU_TYPE_I386;
  }
}

+ (NSString *)baseVersionForSDKShortVersion:(NSString *)shortVersionString
{
  ISHSDKInfo *sdkInfo = [self sdkInfoForShortVersion:shortVersionString];
  DTiPhoneSimulatorSystemRoot *root = [DTiPhoneSimulatorSystemRoot rootWithSDKPath:sdkInfo.root];
  return [root sdkVersion];
}

@end
