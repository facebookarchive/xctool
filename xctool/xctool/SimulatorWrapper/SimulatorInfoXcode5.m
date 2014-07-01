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

#import "SimulatorInfoXcode5.h"

#import "DTiPhoneSimulatorRemoteClient.h"
#import "ISHDeviceInfo.h"
#import "ISHDeviceVersions.h"
#import "ISHSDKInfo.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

static const NSInteger KProductTypeIphone = 1;
static const NSInteger KProductTypeIpad = 2;

@implementation SimulatorInfoXcode5
@synthesize buildSettings = _buildSettings;
@synthesize cpuType = _cpuType;
@synthesize deviceName = _deviceName;
@synthesize OSVersion = _OSVersion;

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

  ISHSDKInfo *sdkInfo = [[ISHDeviceVersions sharedInstance] sdkFromSDKRoot:_buildSettings[Xcode_SDKROOT]];
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
  if (_OSVersion) {
    if ([_OSVersion isEqualTo:@"latest"]) {
      return [[[ISHDeviceVersions sharedInstance] sdkFromSDKRoot:[[ISHDeviceVersions sharedInstance] latestSDKRoot]] shortVersionString];
    } else {
      return _OSVersion;
    }
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
  DTiPhoneSimulatorSystemRoot *systemRoot = [SimulatorInfoXcode5 _systemRootWithSDKVersion:sdkVersion];
  if (systemRoot) {
    return systemRoot;
  }

  systemRoot = [SimulatorInfoXcode5 _systemRootWithSDKVersion:sdkVersion];
  if (!systemRoot) {
    NSArray *availableSdks = [[[ISHDeviceVersions sharedInstance] allSDKs] valueForKeyPath:@"shortVersionString"];
    NSAssert(systemRoot != nil, @"Unable to instantiate DTiPhoneSimulatorSystemRoot for sdk version: %@. Available sdks: %@", sdkVersion, availableSdks);
  }
  return systemRoot;
}

#pragma mark -
#pragma mark Class Methods

+ (NSArray *)availableDevices
{
  return [[ISHDeviceVersions sharedInstance] allDeviceNames];
}

+ (NSString *)deviceNameForAlias:(NSString *)deviceAlias
{
  return deviceAlias;
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
  DTiPhoneSimulatorSystemRoot *root = [self _systemRootWithSDKVersion:shortVersionString];
  return [root sdkVersion];
}

#pragma mark -
#pragma mark Caching methods

+ (DTiPhoneSimulatorSystemRoot *)_systemRootWithSDKPath:(NSString *)path
{
  static NSMutableDictionary *map;
  static dispatch_once_t onceToken;
  static dispatch_queue_t accessQueue;
  dispatch_once(&onceToken, ^{
    map = [@{} mutableCopy];
    accessQueue = dispatch_queue_create("com.xctool.access_root_with_sdk_path", NULL);
  });

  __block DTiPhoneSimulatorSystemRoot *root = nil;
  dispatch_sync(accessQueue, ^{
    root = map[path];
  });

  if (root) {
    return root;
  }

  root = [DTiPhoneSimulatorSystemRoot rootWithSDKPath:path];

  if (root) {
    dispatch_async(accessQueue, ^{
      map[path] = root;
    });
  }

  return root;
}

+ (DTiPhoneSimulatorSystemRoot *)_systemRootWithSDKVersion:(NSString *)version
{
  static NSMutableDictionary *map;
  static dispatch_once_t onceToken;
  static dispatch_queue_t accessQueue;
  dispatch_once(&onceToken, ^{
    map = [@{} mutableCopy];
    accessQueue = dispatch_queue_create("com.xctool.access_root_with_sdk_version", NULL);
  });

  __block DTiPhoneSimulatorSystemRoot *root = nil;
  dispatch_sync(accessQueue, ^{
    root = map[version];
  });

  if (root) {
    return root;
  }

  ISHSDKInfo *sdkInfo = [self sdkInfoForShortVersion:version];
  root = [DTiPhoneSimulatorSystemRoot rootWithSDKPath:sdkInfo.root];

  if (root) {
    dispatch_async(accessQueue, ^{
      map[version] = root;
    });
  }

  return root;
}

@end

#if XCODE_VERSION >= 0600
@implementation ISHSDKInfo
@end
@implementation ISHDeviceVersions
@end
@implementation ISHDeviceInfo
@end
#endif
