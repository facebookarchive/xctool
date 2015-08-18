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

@interface SimulatorInfo ()
@property (nonatomic, assign) cpu_type_t cpuType;
@property (nonatomic, copy) NSString *deviceName;
@property (nonatomic, copy) NSString *OSVersion;

@property (nonatomic, strong) SimDevice *simulatedDevice;
@property (nonatomic, strong) SimRuntime *simulatedRuntime;

@property (nonatomic, copy) NSString *testHostPath;
@property (nonatomic, copy) NSString *productBundlePath;
@property (nonatomic, assign) cpu_type_t testHostPathCpuType;
@property (nonatomic, assign) cpu_type_t productBundlePathCpuType;
@property (nonatomic, assign) cpu_type_t simulatedCpuType;
@end

@implementation SimulatorInfo

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

- (NSString *)simulatedSdkName
{
  if ([_buildSettings[Xcode_SDK_NAME] hasPrefix:@"macosx"]) {
    return _buildSettings[Xcode_SDK_NAME];
  }

  DTiPhoneSimulatorSystemRoot *systemRoot = [self systemRootForSimulatedSdk];
  NSString *platformName = [[[[[systemRoot runtime] platformPath] lastPathComponent] stringByDeletingPathExtension] lowercaseString];
  return [platformName stringByAppendingString:[self simulatedSdkVersion]];
}

- (DTiPhoneSimulatorSystemRoot *)systemRootForSimulatedSdk
{
  NSString *sdkVersion = [self simulatedSdkVersion];
  DTiPhoneSimulatorSystemRoot *systemRoot = [SimulatorInfo _systemRootWithSDKVersion:sdkVersion];
  if (systemRoot) {
    return systemRoot;
  }

  systemRoot = [SimulatorInfo _systemRootWithSDKVersion:sdkVersion];
  NSAssert(systemRoot != nil, @"Unable to instantiate DTiPhoneSimulatorSystemRoot for sdk version: %@. Available roots: %@", sdkVersion, [DTiPhoneSimulatorSystemRoot knownRoots]);
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
    SimDeviceType *deviceType = [SimDeviceType supportedDeviceTypesByAlias][[self simulatedDeviceInfoName]];
    NSAssert(deviceType != nil, @"Unable to find SimDeviceType for the device with name \"%@\". Available device names: %@", [self simulatedDeviceInfoName], [[SimDeviceType supportedDeviceTypesByAlias] allKeys]);
    for (SimDevice *device in [[SimDeviceSet defaultSet] availableDevices]) {
      if ([device.deviceType isEqual:deviceType] &&
          [device.runtime isEqual:runtime]) {
        _simulatedDevice = device;
        break;
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
  } else {
    environment = IOSTestEnvironment(_buildSettings);
    [librariesToInsert addObject:[XCToolLibPath() stringByAppendingPathComponent:@"otest-shim-ios.dylib"]];
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
  return [[SimDeviceType supportedDeviceTypesByName] allKeys];
}

+ (BOOL)isDeviceAvailableWithAlias:(NSString *)deviceName
{
  return [SimDeviceType supportedDeviceTypesByAlias][deviceName] != nil;
}

+ (NSString *)deviceNameForAlias:(NSString *)deviceAlias
{
  SimDeviceType *deviceType = [SimDeviceType supportedDeviceTypesByAlias][deviceAlias];
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
  NSAssert(deviceType != nil, @"Unable to find SimDeviceType for the device with name \"%@\". Available device names: %@", deviceName, [[SimDeviceType supportedDeviceTypesByAlias] allKeys]);
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
  DTiPhoneSimulatorSystemRoot *root = [SimulatorInfo _systemRootWithSDKPath:sdkPath];
  return [root runtime];
}

+ (NSArray *)_availableDeviceConfigurationsInHumanReadableFormat
{
  NSMutableArray *configs = [NSMutableArray array];
  for (SimDevice *device in [[SimDeviceSet defaultSet] availableDevices]) {
    [configs addObject:[NSString stringWithFormat:@"%@: %@", device.name, device.runtime.versionString]];
  }
  return configs;
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

  // In Xcode 6 latest sdk path could be a symlink to iPhoneSimulator.sdk.
  // It should be resolved before comparing with `knownRoots` paths.
  path = [path stringByResolvingSymlinksInPath];

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
