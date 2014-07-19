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

#pragma mark -
#pragma mark Private methods

+ (ISHSDKInfoStub *)sdkInfoForShortVersion:(NSString *)sdkVersion
{
  ISHDeviceVersionsStub *versions = [ISHDeviceVersionsStub sharedInstance];
  for (ISHSDKInfoStub *sdkInfo in [versions allSDKs]) {
    if ([[sdkInfo shortVersionString] isEqualToString:sdkVersion]) {
      return sdkInfo;
    }
  }
  return nil;
}

- (NSString *)maxSdkVersionForSimulatedDevice
{
  ISHDeviceVersionsStub *versions = [ISHDeviceVersionsStub sharedInstance];
  ISHDeviceInfoStub *deviceInfo = [versions deviceInfoNamed:[self simulatedDeviceInfoName]];
  NSAssert(deviceInfo, @"Device info wasn't found for device with name: %@", [self simulatedDeviceInfoName]);
  ISHSDKInfoStub *maxSdk = nil;
  do {
    for (ISHSDKInfoStub *sdkInfo in [versions allSDKs]) {
      if (![deviceInfo supportsSDK:sdkInfo]) {
        continue;
      }
      if ([sdkInfo version] > [maxSdk version]) {
        maxSdk = sdkInfo;
      }
    }
    if (!maxSdk) {
      deviceInfo = [deviceInfo newerEquivalent];
    } else {
      break;
    }
    if (!deviceInfo) {
      NSArray *availableSdks = [[[ISHDeviceVersionsStub sharedInstance] allSDKs] valueForKeyPath:@"shortVersionString"];
      NSArray *availableDevices = [[ISHDeviceVersionsStub sharedInstance] allDeviceNames];
      NSAssert(deviceInfo, @"There are not comptable devices and SDKs to simulate. Available devices: %@, sdk: %@", availableDevices, availableSdks);
    }
  } while (true);
  
  // set device name in case if it was changed
  self.deviceName = [deviceInfo displayName];
  
  return [maxSdk shortVersionString];
}

#pragma mark -
#pragma mark Public methods

- (NSNumber *)launchTimeout
{
  NSString *launchTimeoutString = self.buildSettings[Xcode_LAUNCH_TIMEOUT];
  if (launchTimeoutString) {
    return @(launchTimeoutString.intValue);
  }
  return @30;
}

- (NSNumber *)simulatedDeviceFamily
{
  return @([_buildSettings[Xcode_TARGETED_DEVICE_FAMILY] integerValue]);
}

- (NSString *)simulatedDeviceInfoName
{
  if (_deviceName) {
    return _deviceName;
  }

  switch ([[self simulatedDeviceFamily] integerValue]) {
    case KProductTypeIphone:
      self.deviceName = @"iPhone";
      break;

    case KProductTypeIpad:
      self.deviceName = @"iPad";
      break;
  }

  ISHSDKInfoStub *sdkInfo = [[ISHDeviceVersionsStub sharedInstance] sdkFromSDKRoot:_buildSettings[Xcode_SDKROOT]];
  if (!sdkInfo) {
    return _deviceName;
  }

  ISHDeviceVersionsStub *versions = [ISHDeviceVersionsStub sharedInstance];
  ISHDeviceInfoStub *deviceInfo = [versions deviceInfoNamed:_deviceName];
  while (deviceInfo && ![deviceInfo supportsSDK:sdkInfo]) {
    deviceInfo = [deviceInfo newerEquivalent];
    self.deviceName = [deviceInfo displayName];
  }

  return _deviceName;
}

- (NSString *)simulatedArchitecture
{
  switch (_cpuType) {
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
      return [[[ISHDeviceVersionsStub sharedInstance] sdkFromSDKRoot:[[ISHDeviceVersionsStub sharedInstance] latestSDKRoot]] shortVersionString];
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
  ISHSDKInfoStub *sdkInfo = [[ISHDeviceVersionsStub sharedInstance] sdkFromSDKRoot:[self simulatedSdkRootPath]];
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
    NSArray *availableSdks = [[[ISHDeviceVersionsStub sharedInstance] allSDKs] valueForKeyPath:@"shortVersionString"];
    NSAssert(systemRoot != nil, @"Unable to instantiate DTiPhoneSimulatorSystemRoot for sdk version: %@. Available sdks: %@", sdkVersion, availableSdks);
  }
  return systemRoot;
}

#pragma mark -
#pragma mark Class Methods

+ (NSArray *)availableDevices
{
  return [[ISHDeviceVersionsStub sharedInstance] allDeviceNames];
}

+ (NSString *)deviceNameForAlias:(NSString *)deviceAlias
{
  return deviceAlias;
}

+ (BOOL)isDeviceAvailableWithAlias:(NSString *)deviceName
{
  return [[ISHDeviceVersionsStub sharedInstance] deviceInfoNamed:deviceName] != nil;
}

+ (ISHSDKInfoStub *)sdkWithVersion:(NSString *)sdkVersion
{
  __block ISHSDKInfoStub *sdkInfo = nil;
  [[[ISHDeviceVersionsStub sharedInstance] allSDKs] enumerateObjectsUsingBlock:^(ISHSDKInfoStub *currentSdkInfo, NSUInteger idx, BOOL *stop) {
    if ([[currentSdkInfo shortVersionString] hasPrefix:sdkVersion]) {
      sdkInfo = currentSdkInfo;
      *stop = YES;
    }
  }];
  return sdkInfo;
}

+ (BOOL)isSdkVersion:(NSString *)sdkVersion supportedByDevice:(NSString *)deviceName
{
  ISHDeviceInfoStub *deviceInfo = [[ISHDeviceVersionsStub sharedInstance] deviceInfoNamed:deviceName];
  ISHSDKInfoStub *sdkInfo = [self sdkWithVersion:sdkVersion];
  return [deviceInfo supportsSDK:sdkInfo];
}

+ (NSString *)sdkVersionForOSVersion:(NSString *)osVersion
{
  ISHSDKInfoStub *sdkInfo = nil;
  if ([osVersion isEqualToString:@"latest"]) {
    sdkInfo = [[ISHDeviceVersionsStub sharedInstance] sdkFromSDKRoot:[[ISHDeviceVersionsStub sharedInstance] latestSDKRoot]];
  } else {
    sdkInfo = [self sdkWithVersion:osVersion];
  }
  return [sdkInfo shortVersionString];
}

+ (NSArray *)availableSdkVersions
{
  return [[[ISHDeviceVersionsStub sharedInstance] allSDKs] valueForKeyPath:@"shortVersionString"];
}

+ (NSArray *)sdksSupportedByDevice:(NSString *)deviceName
{
  ISHDeviceInfoStub *deviceInfo = [[ISHDeviceVersionsStub sharedInstance] deviceInfoNamed:deviceName];
  NSMutableArray *supportedSdks = [NSMutableArray array];
  for (ISHSDKInfoStub *sdk in [[ISHDeviceVersionsStub sharedInstance] allSDKs]) {
    if ([deviceInfo supportsSDK:sdk]) {
      [supportedSdks addObject:sdk];
    }
  }
  return supportedSdks;
}

+ (cpu_type_t)cpuTypeForDevice:(NSString *)deviceName
{
  ISHDeviceInfoStub *deviceInfo = [[ISHDeviceVersionsStub sharedInstance] deviceInfoNamed:deviceName];
  if ([[deviceInfo architecture] isEqualToString:@"x86_64"]) {
    return CPU_TYPE_X86_64;
  } else {
    return CPU_TYPE_I386;
  }
}

+ (NSString *)baseVersionForSDKShortVersion:(NSString *)shortVersionString
{
  DTiPhoneSimulatorSystemRoot *root = [self _systemRootWithSDKVersion:shortVersionString];
  NSArray *components = [[root sdkVersion] componentsSeparatedByString:@"."];
  if ([components count] < 2) {
    return [root sdkVersion];
  }
  return [[components objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)]] componentsJoinedByString:@"."];
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

  ISHSDKInfoStub *sdkInfo = [self sdkInfoForShortVersion:version];
  root = [DTiPhoneSimulatorSystemRoot rootWithSDKPath:sdkInfo.root];

  if (root) {
    dispatch_async(accessQueue, ^{
      map[version] = root;
    });
  }

  return root;
}

@end

/*
 *  In order to make xctool linkable in Xcode 6 we need to provide stub implementations
 *  of iOS simulator private classes used in xctool and defined in
 *  the SimulatorHost framework (introduced in Xcode 5 and deprecated in Xcode 6).
 *
 *  But xctool, when built with Xcode 6 but running in Xcode 5, should use the
 *  implementations of those classes from SimulatorHost framework rather than the stub
 *  implementations. That is why we need to create stubs and forward all selector
 *  invocations to the original implementation of the class if it exists.
 */

#if XCODE_VERSION >= 0600

void LoadFrameworkIfNeeded()
{
  static Class principalClass;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    if (![[[[NSBundle allFrameworks] valueForKeyPath:@"bundlePath"] valueForKey:@"lastPathComponent"] containsObject:@"SimulatorHost.framework"]) {
      NSString *frameworkPath = [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks/SimulatorHost.framework"];
      NSBundle *bundle = [NSBundle bundleWithPath:frameworkPath];
      principalClass = [bundle principalClass];
    }
  });
}

@implementation ISHSDKInfoStub
+ (id)forwardingTargetForSelector:(SEL)aSelector
{
  LoadFrameworkIfNeeded();
  Class class = NSClassFromString(@"ISHSDKInfo");
  NSAssert(class, @"Class ISHSDKInfo wasn't found though it was expected to exist.");
  return class;
}
@end

@implementation ISHDeviceVersionsStub
+ (id)forwardingTargetForSelector:(SEL)aSelector
{
  LoadFrameworkIfNeeded();
  Class class = NSClassFromString(@"ISHDeviceVersions");
  NSAssert(class, @"Class ISHDeviceVersions wasn't found though it was expected to exist.");
  return class;
}
@end

@implementation ISHDeviceInfoStub
+ (id)forwardingTargetForSelector:(SEL)aSelector
{
  LoadFrameworkIfNeeded();
  Class class = NSClassFromString(@"ISHDeviceInfo");
  NSAssert(class, @"Class ISHDeviceInfo wasn't found though it was expected to exist.");
  return class;
}
@end

#else

/*
 *  If xctool is built using Xcode 5 then we just need to provide empty implementations
 *  of the stubs because they simply inherit original SimulatorHost private classes in
 *  that case.
 */

@implementation ISHSDKInfoStub
@end
@implementation ISHDeviceVersionsStub
@end
@implementation ISHDeviceInfoStub
@end

#endif
