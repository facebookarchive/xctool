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

#import <Foundation/Foundation.h>

#import "SimulatorInfo.h"

#import "DTiPhoneSimulatorRemoteClient.h"
#import "SimDevice.h"
#import "SimDeviceSet.h"
#import "SimDeviceType.h"
#import "SimRuntime.h"
#import "XcodeBuildSettings.h"
#import "XCToolUtil.h"

static const NSInteger KProductTypeIphone = 1;
static const NSInteger KProductTypeIpad = 2;

@interface DTiPhoneSimulatorSystemRoot (PlatformName)
- (NSString *)platformName;
@end

@implementation DTiPhoneSimulatorSystemRoot (PlatformName)
- (NSString *)platformName
{
  return [[[[[self runtime] platformPath] lastPathComponent] stringByDeletingPathExtension] lowercaseString];
}
@end

@interface SimulatorInfo ()
@property (nonatomic, assign) cpu_type_t cpuType;
@property (nonatomic, copy) NSString *deviceName;
@property (nonatomic, copy) NSString *OSVersion;
@property (nonatomic, copy) NSUUID *deviceUDID;

@property (nonatomic, strong) SimDevice *simulatedDevice;
@property (nonatomic, strong) SimRuntime *simulatedRuntime;

@property (nonatomic, copy) NSString *testHostPath;
@property (nonatomic, copy) NSString *productBundlePath;
@property (nonatomic, assign) cpu_type_t testHostPathCpuType;
@property (nonatomic, assign) cpu_type_t productBundlePathCpuType;
@property (nonatomic, assign) cpu_type_t simulatedCpuType;
@end

@implementation SimulatorInfo

+ (void)prepare
{
  NSAssert([NSThread isMainThread], @"Should be called on main thread");
  [self _warmUpDTiPhoneSimulatorSystemRootCaches];
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _cpuType = CPU_TYPE_ANY;
    _testHostPathCpuType = 0;
    _productBundlePathCpuType = 0;
    _simulatedCpuType = 0;
  }
  return self;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
  SimulatorInfo *copy = [[SimulatorInfo allocWithZone:zone] init];
  if (copy) {
    copy.buildSettings = _buildSettings;
    copy.cpuType = _cpuType;
    copy.deviceName = _deviceName;
    copy.OSVersion = _OSVersion;
    copy.deviceUDID = _deviceUDID;
  }
  return copy;
}

#pragma mark - Internal Methods

- (void)setBuildSettings:(NSDictionary *)buildSettings
{
  if (_buildSettings == buildSettings || [_buildSettings isEqual:buildSettings]) {
    return;
  }

  _buildSettings = [buildSettings copy];
  _testHostPath = nil;
  _productBundlePath = nil;
  _testHostPathCpuType = 0;
  _productBundlePathCpuType = 0;
  _simulatedCpuType = 0;
}

- (NSString *)testHostPath
{
  if (!_testHostPath) {
    _testHostPath = TestHostPathForBuildSettings(_buildSettings);
  }
  return _testHostPath;
}

- (NSString *)productBundlePath
{
  if (!_productBundlePath) {
    _productBundlePath = ProductBundlePathForBuildSettings(_buildSettings);
  }
  return _productBundlePath;
}

- (cpu_type_t)testHostPathCpuType
{
  if (_testHostPathCpuType == 0) {
    _testHostPathCpuType = CpuTypeForTestBundleAtPath([self testHostPath]);
  }
  return _testHostPathCpuType;
}

- (cpu_type_t)productBundlePathCpuType
{
  if (_productBundlePathCpuType == 0) {
    _productBundlePathCpuType = CpuTypeForTestBundleAtPath([self productBundlePath]);
  }
  return _productBundlePathCpuType;
}

#pragma mark -
#pragma mark Public methods

- (cpu_type_t)simulatedCpuType
{
  if (_cpuType != CPU_TYPE_ANY) {
    return _cpuType;
  }

  if (_simulatedCpuType == 0) {
    /*
     * We use architecture of test host rather than product bundle one
     * if they don't match and test host doesn't support all architectures.
     */
    if ([self testHostPathCpuType] == CPU_TYPE_ANY) {
      _simulatedCpuType = [self productBundlePathCpuType];
    } else {
      _simulatedCpuType = [self testHostPathCpuType];
    }
  }

  return _simulatedCpuType;
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

  if ([_buildSettings[Xcode_SDK_NAME] hasPrefix:@"macosx"]) {
    return @"My Mac";
  }

  switch ([[self simulatedDeviceFamily] integerValue]) {
    case KProductTypeIphone:
      if ([self simulatedCpuType] == CPU_TYPE_I386) {
        _deviceName = @"iPhone 4s";
      } else {
        // CPU_TYPE_X86_64 or CPU_TYPE_ANY
        _deviceName = @"iPhone 5s";
      }
      break;

    case KProductTypeIpad:
      if ([self simulatedCpuType] == CPU_TYPE_I386) {
        _deviceName = @"iPad 2";
      } else {
        // CPU_TYPE_X86_64 or CPU_TYPE_ANY
        _deviceName = @"iPad Air";
      }
      break;
  }

  DTiPhoneSimulatorSystemRoot *systemRoot = [SimulatorInfo _systemRootWithSDKPath:_buildSettings[Xcode_SDKROOT]];
  if (!systemRoot) {
    return _deviceName;
  }

  // return lowest device that has configuration with simulated sdk where lowest is defined
  // by the order in the returned array of devices from `-[SimDeviceSet availableDevices]`
  SimRuntime *runtime = systemRoot.runtime;
  NSMutableArray *supportedDeviceTypes = [NSMutableArray array];
  for (SimDevice *device in [[SimDeviceSet defaultSet] availableDevices]) {
    if (![device.runtime isEqual:runtime]) {
      continue;
    }

    if ([self simulatedCpuType] == CPU_TYPE_ANY ||
        [[[device deviceType] supportedArchs] containsObject:@([self simulatedCpuType])]) {
      [supportedDeviceTypes addObject:device.deviceType];
      // we need only first one
      break;
    }
  }

  NSAssert([supportedDeviceTypes count] > 0, @"There are no available devices that support provided sdk: %@. Supported devices: %@", [systemRoot sdkVersion], [[SimDeviceType supportedDevices] valueForKeyPath:@"name"]);
  _deviceName = [supportedDeviceTypes[0] name];
  return _deviceName;
}

- (NSString *)simulatedArchitecture
{
  switch ([self simulatedCpuType]) {
    case CPU_TYPE_I386:
      return @"i386";

    case CPU_TYPE_X86_64:
      return @"x86_64";
  }
  return @"i386";
}

- (NSString *)maxSdkVersionForSimulatedDevice
{
  NSMutableArray *runtimes = [SimulatorInfo _runtimesSupportedByDevice:[self simulatedDeviceInfoName]];
  [runtimes sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"version" ascending:YES]]];
  return [[runtimes lastObject] versionString];
}

- (NSString *)simulatedSdkVersion
{
  if (_OSVersion && ![_OSVersion isEqualToString:@"latest"]) {
    return _OSVersion;
  }
  return [self maxSdkVersionForSimulatedDevice];
}

- (NSString *)simulatedSdkRootPath
{
  return [[self systemRootForSimulatedSdk] sdkRootPath];
}

- (NSString *)simulatedSdkShortVersion
{
  return [[[self systemRootForSimulatedSdk] runtime] versionString];
}

- (NSString *)simulatedSdkName
{
  if ([_buildSettings[Xcode_SDK_NAME] hasPrefix:@"macosx"]) {
    return _buildSettings[Xcode_SDK_NAME];
  }

  DTiPhoneSimulatorSystemRoot *systemRoot = [self systemRootForSimulatedSdk];
  NSString *platformName = [systemRoot platformName];
  return [platformName stringByAppendingString:[self simulatedSdkVersion]];
}

- (DTiPhoneSimulatorSystemRoot *)systemRootForSimulatedSdk
{
  NSString *platform = _buildSettings[Xcode_PLATFORM_NAME];
  if (!platform) {
    platform = [[[_buildSettings[Xcode_PLATFORM_DIR] lastPathComponent] stringByDeletingPathExtension] lowercaseString];
  }
  NSAssert([platform isEqualToString:@"iphonesimulator"] || [platform isEqualToString:@"macosx"] || [platform isEqualToString:@"appletvsimulator"], @"Platform '%@' is not yet supported.", platform);
  NSString *sdkVersion = [self simulatedSdkVersion];
  DTiPhoneSimulatorSystemRoot *systemRoot = [SimulatorInfo _systemRootForPlatform:platform sdkVersion:sdkVersion];
  NSAssert(systemRoot != nil, @"Unable to instantiate DTiPhoneSimulatorSystemRoot for platform %@ and sdk version %@. Available roots: %@", platform, sdkVersion, [DTiPhoneSimulatorSystemRoot knownRoots]);
  return systemRoot;
}

- (SimRuntime *)simulatedRuntime
{
  if (!_simulatedRuntime) {
    _simulatedRuntime = [[self systemRootForSimulatedSdk] runtime];
    NSAssert(_simulatedRuntime != nil, @"Unable to find simulated runtime for simulated sdk of version %@ at path %@. Supported runtimes: %@", [[self systemRootForSimulatedSdk] sdkVersion], [[self systemRootForSimulatedSdk] sdkRootPath], [SimRuntime supportedRuntimes]);
  }
  return _simulatedRuntime;
}

- (SimDevice *)simulatedDevice
{
  if (!_simulatedDevice) {
    SimRuntime *runtime = [self simulatedRuntime];
    if (_deviceUDID) {
      return [SimulatorInfo deviceWithUDID:_deviceUDID];
    } else {
      SimDeviceType *deviceType = [SimDeviceType supportedDeviceTypesByAlias][[self simulatedDeviceInfoName]];
      NSAssert(deviceType != nil, @"Unable to find SimDeviceType for the device with name \"%@\". Available device names: %@", [self simulatedDeviceInfoName], [[SimDeviceType supportedDeviceTypesByAlias] allKeys]);
      for (SimDevice *device in [[SimDeviceSet defaultSet] availableDevices]) {
        if ([device.deviceType isEqual:deviceType] &&
            [device.runtime isEqual:runtime]) {
          _simulatedDevice = device;
          break;
        }
      }
    }

    NSAssert(_simulatedDevice != nil, @"Simulator with name \"%@\" doesn't have configuration with sdk version \"%@\". Available configurations: %@.", [self simulatedDeviceInfoName], runtime.versionString, [SimulatorInfo _availableDeviceConfigurationsInHumanReadableFormat]);
  }
  return _simulatedDevice;
}

- (NSNumber *)launchTimeout
{
  NSString *launchTimeoutString = _buildSettings[Xcode_LAUNCH_TIMEOUT];
  if (launchTimeoutString) {
    return @(launchTimeoutString.intValue);
  }
  return @30;
}

/*
 * Passing the same simulator environment as Xcode 6.4.
 */
- (NSMutableDictionary *)simulatorLaunchEnvironment
{
  NSString *sdkName = _buildSettings[Xcode_SDK_NAME];
  NSString *ideBundleInjectionLibPath = [_buildSettings[Xcode_PLATFORM_DIR] stringByAppendingPathComponent:@"Developer/Library/PrivateFrameworks/IDEBundleInjection.framework/IDEBundleInjection"];
  NSMutableDictionary *environment = nil;
  NSMutableArray *librariesToInsert = [NSMutableArray arrayWithObject:ideBundleInjectionLibPath];
  if ([sdkName hasPrefix:@"macosx"]) {
    environment = OSXTestEnvironment(_buildSettings);
    [librariesToInsert addObject:[XCToolLibPath() stringByAppendingPathComponent:@"otest-shim-osx.dylib"]];
  } else if ([sdkName hasPrefix:@"iphonesimulator"]) {
    environment = IOSTestEnvironment(_buildSettings);
    [librariesToInsert addObject:[XCToolLibPath() stringByAppendingPathComponent:@"otest-shim-ios.dylib"]];
  } else if ([sdkName hasPrefix:@"appletvsimulator"]) {
    environment = TVOSTestEnvironment(_buildSettings);
    [librariesToInsert addObject:[XCToolLibPath() stringByAppendingPathComponent:@"otest-shim-ios.dylib"]];
  } else {
    NSAssert(false, @"'%@' sdk is not yet supported", sdkName);
  }

  [environment addEntriesFromDictionary:@{
    @"DYLD_INSERT_LIBRARIES" : [librariesToInsert componentsJoinedByString:@":"],
    @"NSUnbufferedIO" : @"YES",
    @"XCInjectBundle" : [self productBundlePath],
    @"XCInjectBundleInto" : [self testHostPath],
    @"AppTargetLocation": [self testHostPath],
    @"TestBundleLocation": [self productBundlePath],
  }];

  return environment;
}

#pragma mark -
#pragma mark Class Methods

+ (NSArray *)availableDevices
{
  return [[SimDeviceType supportedDeviceTypes] valueForKeyPath:@"name"];
}

+ (BOOL)isDeviceAvailableWithAlias:(NSString *)deviceName
{
  return [SimDeviceType supportedDeviceTypesByAlias][deviceName] != nil;
}

+ (SimDevice *)deviceWithUDID:(NSUUID *)deviceUDID
{
  for (SimDevice *device in [[SimDeviceSet defaultSet] availableDevices]) {
    if ([device.UDID isEqual:deviceUDID]) {
      return device;
    }
  }
  return nil;
}

+ (NSString *)deviceNameForAlias:(NSString *)deviceAlias
{
  SimDeviceType *deviceType = [SimDeviceType supportedDeviceTypesByAlias][deviceAlias];
  return [deviceType name];
}

+ (BOOL)isSdkVersion:(NSString *)sdkVersion supportedByDevice:(NSString *)deviceName
{
  NSAssert(sdkVersion != nil, @"Sdk version shouldn't be nil.");
  NSMutableArray *runtimes = [self _runtimesSupportedByDevice:deviceName];
  if ([runtimes count] == 0) {
    return NO;
  }

  if ([sdkVersion isEqualToString:@"latest"]) {
    return YES;
  }

  for (SimRuntime *runtime in runtimes) {
    if ([runtime.versionString hasPrefix:sdkVersion]) {
      return YES;
    }
  }

  return NO;
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

#pragma mark -
#pragma mark Helpers

+ (NSMutableArray *)_runtimesSupportedByDevice:(NSString *)deviceName
{
  NSMutableArray *supportedRuntimes = [NSMutableArray array];
  SimDeviceType *deviceType = [SimDeviceType supportedDeviceTypesByAlias][deviceName];
  NSAssert(deviceType != nil, @"Unable to find SimDeviceType for the device with name \"%@\". Available device names: %@", deviceName, [[SimDeviceType supportedDeviceTypesByAlias] allKeys]);
  for (SimRuntime *runtime in [SimRuntime supportedRuntimes]) {
    if ([runtime supportsDeviceType:deviceType]) {
      [supportedRuntimes addObject:runtime];
    }
  }
  return supportedRuntimes;
}

+ (SimRuntime *)_runtimeForSDKPath:(NSString *)sdkPath
{
  DTiPhoneSimulatorSystemRoot *root = [SimulatorInfo _systemRootWithSDKPath:sdkPath];
  return [root runtime];
}

+ (NSArray *)_availableDeviceConfigurationsInHumanReadableFormat
{
  NSMutableArray *configs = [NSMutableArray array];
  for (SimDevice *device in [[SimDeviceSet defaultSet] availableDevices]) {
    [configs addObject:[NSString stringWithFormat:@"%@: %@", device.name, device.runtime.name]];
  }
  return configs;
}

#pragma mark -
#pragma mark Caching methods

/*
 * Caches `DTiPhoneSimulatorSystemRoot` instances.
 *
 * `sdkRootPath` -> `DTiPhoneSimulatorSystemRoot *`
 * `platformName` -> `NSDictionary *`: `sdkVersion` -> `DTiPhoneSimulatorSystemRoot *`
 *
 */
static NSDictionary *__systemRootsSdkPlatformVersionMap;
static NSDictionary *__systemRootsSdkPathMap;

+ (void)_warmUpDTiPhoneSimulatorSystemRootCaches
{
  // cache system roots
  NSArray *roots = [DTiPhoneSimulatorSystemRoot knownRoots];

  // create a map
  NSMutableDictionary *platformVersionMap = [NSMutableDictionary new];
  NSMutableDictionary *pathMap = [NSMutableDictionary new];
  for (DTiPhoneSimulatorSystemRoot *root in roots) {
    pathMap[root.sdkRootPath] = root;
    if (!platformVersionMap[root.platformName]) {
      platformVersionMap[root.platformName] = [NSMutableDictionary dictionary];
    }
    platformVersionMap[root.platformName][root.sdkVersion] = root;
  }
  __systemRootsSdkPlatformVersionMap = [platformVersionMap copy];
  __systemRootsSdkPathMap = [pathMap copy];
}

+ (DTiPhoneSimulatorSystemRoot *)_systemRootWithSDKPath:(NSString *)path
{
  // In Xcode 6 latest sdk path could be a symlink to iPhoneSimulator.sdk.
  // It should be resolved before comparing with `knownRoots` paths.
  path = [path stringByResolvingSymlinksInPath];
  return __systemRootsSdkPathMap[path];
}

+ (DTiPhoneSimulatorSystemRoot *)_systemRootForPlatform:(NSString *)platform sdkVersion:(NSString *)version
{
  for (NSString *cachedPlatform in  __systemRootsSdkPlatformVersionMap) {
    // sometimes platform may include version, for example, iphonesimulator9.2
    if ([cachedPlatform commonPrefixWithString:platform options:NSCaseInsensitiveSearch].length < 5) {
      continue;
    }
    NSDictionary *versions = __systemRootsSdkPlatformVersionMap[cachedPlatform];
    for (NSString *cachedVersion in versions) {
      // sdk version of system root usually consists of 2 numbers, like 9.2
      // but requested sdk version could have 3 numbers, like 9.2.1.
      if ([cachedVersion hasPrefix:version] || [version hasPrefix:cachedVersion]) {
        return versions[cachedVersion];
      }
    }
    break;
  }
  return nil;
}

@end
