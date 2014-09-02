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

#import "SimulatorInfoXcode6.h"

#import "DTiPhoneSimulatorRemoteClient.h"
#import "SimDevice.h"
#import "SimDeviceSet.h"
#import "SimDeviceType.h"
#import "SimRuntime.h"
#import "XcodeBuildSettings.h"
#import "XCToolUtil.h"

static const NSInteger KProductTypeIphone = 1;
static const NSInteger KProductTypeIpad = 2;

@interface SimRuntime (Latest)
+ (SimRuntime *)latest;
@end

@implementation SimRuntime (Latest)

+ (SimRuntime *)latest
{
  NSArray *sorted = [[SimRuntime supportedRuntimes] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"version" ascending:YES]]];
  return [sorted lastObject];
}

@end

@interface SimulatorInfoXcode6 ()
@property (nonatomic, retain) SimDevice *simulatedDevice;
@property (nonatomic, retain) SimRuntime *simulatedRuntime;
@end

@implementation SimulatorInfoXcode6
@synthesize buildSettings = _buildSettings;
@synthesize cpuType = _cpuType;
@synthesize deviceName = _deviceName;
@synthesize OSVersion = _OSVersion;

- (void)dealloc
{
  [_buildSettings release];
  [_deviceName release];
  [_OSVersion release];
  [super dealloc];
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

  switch ([[self simulatedDeviceFamily] integerValue]) {
    case KProductTypeIphone:
      self.deviceName = @"iPhone 4s";
      break;

    case KProductTypeIpad:
      self.deviceName = @"iPad 2";
      break;
  }

  DTiPhoneSimulatorSystemRoot *systemRoot = [SimulatorInfoXcode6 _systemRootWithSDKPath:_buildSettings[Xcode_SDKROOT]];
  if (!systemRoot) {
    return _deviceName;
  }

  // return lowest device that supports simulated sdk
  SimRuntime *runtime = systemRoot.runtime;
  NSMutableArray *supportedDeviceTypes = [NSMutableArray array];
  for (SimDeviceType *deviceType in [SimDeviceType supportedDeviceTypes]) {
    if ([runtime supportsDeviceType:deviceType]) {
      [supportedDeviceTypes addObject:deviceType];
    }
  }

  NSAssert([supportedDeviceTypes count] > 0, @"There are no available devices that support provided sdk: %@. Supported devices: %@", [systemRoot sdkVersion], [[SimDeviceType supportedDevices] valueForKeyPath:@"name"]);
  self.deviceName = [supportedDeviceTypes[0] name];
  return _deviceName;
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

- (NSString *)maxSdkVersionForSimulatedDevice
{
  NSMutableArray *runtimes = [SimulatorInfoXcode6 _runtimesSupportedByDevice:[self simulatedDeviceInfoName]];
  [runtimes sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"version" ascending:YES]]];
  return [[runtimes lastObject] versionString];
}

- (NSString *)simulatedSdkVersion
{
  if (_OSVersion) {
    if ([_OSVersion isEqualTo:@"latest"]) {
      return [[SimRuntime latest] versionString];
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
  return [[[self systemRootForSimulatedSdk] runtime] versionString];
}

- (DTiPhoneSimulatorSystemRoot *)systemRootForSimulatedSdk
{
  NSString *sdkVersion = [self simulatedSdkVersion];
  DTiPhoneSimulatorSystemRoot *systemRoot = [SimulatorInfoXcode6 _systemRootWithSDKVersion:sdkVersion];
  if (systemRoot) {
    return systemRoot;
  }

  systemRoot = [SimulatorInfoXcode6 _systemRootWithSDKVersion:sdkVersion];
  NSAssert(systemRoot != nil, @"Unable to instantiate DTiPhoneSimulatorSystemRoot for sdk version: %@. Available roots: %@", sdkVersion, [DTiPhoneSimulatorSystemRoot knownRoots]);
  return systemRoot;
}

#pragma mark -
#pragma mark v6 methods

- (SimRuntime *)simulatedRuntime
{
  if (!_simulatedRuntime) {
    _simulatedRuntime = [[self systemRootForSimulatedSdk] runtime];
  }
  return _simulatedRuntime;
}

- (SimDevice *)simulatedDevice
{
  if (!_simulatedDevice) {
    SimRuntime *runtime = [self simulatedRuntime];
    SimDeviceType *deviceType = [SimDeviceType supportedDeviceTypesByAlias][[self simulatedDeviceInfoName]];
    for (SimDevice *device in [[SimDeviceSet defaultSet] availableDevices]) {
      if ([device.deviceType isEqual:deviceType] &&
          [device.runtime isEqual:runtime]) {
        _simulatedDevice = device;
        break;
      }
    }
  }
  return _simulatedDevice;
}

#pragma mark -
#pragma mark Class Methods

+ (NSArray *)availableDevices
{
  return [[SimDeviceType supportedDeviceTypesByName] allKeys];
}

+ (BOOL)isDeviceAvailableWithAlias:(NSString *)deviceName
{
  return [[SimDeviceType supportedDeviceTypesByAlias] objectForKey:deviceName] != nil;
}

+ (NSString *)deviceNameForAlias:(NSString *)deviceAlias
{
  SimDeviceType *deviceType = [[SimDeviceType supportedDeviceTypesByAlias] objectForKey:deviceAlias];
  return [deviceType name];
}

+ (BOOL)isSdkVersion:(NSString *)sdkVersion supportedByDevice:(NSString *)deviceName
{
  SimDeviceType *deviceType = [SimDeviceType supportedDeviceTypesByAlias][deviceName];
  SimRuntime *runtime = [self _runtimeForSdkVersion:sdkVersion];

  return [runtime supportsDeviceType:deviceType];
}

+ (NSString *)sdkVersionForOSVersion:(NSString *)osVersion
{
  if ([osVersion isEqualToString:@"latest"]) {
    return [[SimRuntime latest] versionString];
  } else {
    return [[self _runtimeForSdkVersion:osVersion] versionString];
  }
}

+ (NSArray *)availableSdkVersions
{
  return [[SimRuntime supportedRuntimes] valueForKeyPath:@"versionString"];
}

+ (NSArray *)sdksSupportedByDevice:(NSString *)deviceName
{
  NSArray *runtimes = [self _runtimesSupportedByDevice:deviceName];
  return [runtimes valueForKeyPath:@"versionString"];
}

+ (cpu_type_t)cpuTypeForDevice:(NSString *)deviceName
{
  SimDeviceType *deviceType = [SimDeviceType supportedDeviceTypesByAlias][deviceName];
  if ([deviceType.supportedArchs containsObject:@(CPU_TYPE_X86_64)]) {
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
#pragma mark Helpers

+ (NSMutableArray *)_runtimesSupportedByDevice:(NSString *)deviceName
{
  NSMutableArray *supportedRuntimes = [NSMutableArray array];
  SimDeviceType *deviceType = [SimDeviceType supportedDeviceTypesByAlias][deviceName];
  NSAssert(deviceType != nil, @"SimDeviceType wasn't found for device with alias: %@. Available aliases: %@", deviceName, [SimDeviceType supportedDeviceTypesByAlias]);
  for (SimRuntime *runtime in [SimRuntime supportedRuntimes]) {
    if ([runtime supportsDeviceType:deviceType]) {
      [supportedRuntimes addObject:runtime];
    }
  }
  return supportedRuntimes;
}

+ (SimRuntime *)_runtimeForSdkVersion:(NSString *)sdkVersion
{
  NSAssert(sdkVersion != nil, @"Sdk version shouldn't be nil.");
  NSArray *runtimes = [SimRuntime supportedRuntimes];
  for (SimRuntime *runtime in runtimes) {
    if ([runtime.versionString hasPrefix:sdkVersion]) {
      return runtime;
    }
  }
  return nil;
}

+ (SimRuntime *)_runtimeForSDKPath:(NSString *)sdkPath
{
  DTiPhoneSimulatorSystemRoot *root = [SimulatorInfoXcode6 _systemRootWithSDKPath:sdkPath];
  return [root runtime];
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

  [[DTiPhoneSimulatorSystemRoot knownRoots] enumerateObjectsUsingBlock:^(DTiPhoneSimulatorSystemRoot *obj, NSUInteger idx, BOOL *stop) {
    if ([obj.sdkRootPath isEqual:path]) {
      root = obj;
      *stop = YES;
    }
  }];

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

  [[DTiPhoneSimulatorSystemRoot knownRoots] enumerateObjectsUsingBlock:^(DTiPhoneSimulatorSystemRoot *obj, NSUInteger idx, BOOL *stop) {
    if ([obj.sdkVersion hasPrefix:version]) {
      root = obj;
      *stop = YES;
    }
  }];

  if (root) {
    dispatch_async(accessQueue, ^{
      map[version] = root;
    });
  }

  return root;
}

@end
