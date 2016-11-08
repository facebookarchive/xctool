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
#import "SimServiceContext.h"
#import "XcodeBuildSettings.h"
#import "XCToolUtil.h"

static const NSInteger KProductTypeIphone = 1;
static const NSInteger KProductTypeIpad = 2;

@interface SimulatorInfo ()
@property (nonatomic, assign) cpu_type_t cpuType;
@property (nonatomic, copy) NSString *deviceName;
@property (nonatomic, copy) NSString *OSVersion;
@property (nonatomic, copy) NSUUID *deviceUDID;

@property (nonatomic, strong) SimServiceContext *simulatedServiceContext;
@property (nonatomic, strong) SimDeviceSet *simulatedDeviceSet;
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
  [self _warmUpSimulatorsInfo];
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _cpuType = CPU_TYPE_ANY;
    _testHostPathCpuType = 0;
    _productBundlePathCpuType = 0;
    if (ToolchainIsXcode81OrBetter()) {
      NSError *error = nil;
      _simulatedServiceContext = [SimServiceContext sharedServiceContextForDeveloperDir:XcodeDeveloperDirPath() error:&error];
      NSAssert(_simulatedServiceContext != nil, @"Failed to inialize simulated service context with error: %@", error);
      _simulatedDeviceSet = [_simulatedServiceContext defaultDeviceSetWithError:&error];
      NSAssert(_simulatedDeviceSet != nil, @"Failed to create default device set for %@ with error: %@", _simulatedServiceContext, error);
    } else {
      _simulatedDeviceSet = [SimDeviceSet defaultSet];
    }
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
        _deviceName = @"iPhone 5";
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

  SimRuntime *runtime = [self _runtimeWithSDKPath:_buildSettings[Xcode_SDKROOT]];
  if (runtime == nil) {
    return _deviceName;
  }
  NSMutableArray *supportedDeviceTypes = [NSMutableArray array];
  for (SimDevice *device in [_simulatedDeviceSet availableDevices]) {
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

  NSAssert([supportedDeviceTypes count] > 0, @"There are no available devices that support provided sdk: %@. Supported devices: %@", [runtime name], [[SimDeviceType supportedDevices] valueForKeyPath:@"name"]);
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
  NSMutableArray *runtimes = [self _runtimesSupportedByDevice:[self simulatedDeviceInfoName]];
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
  return [self sdkInfoForSimulatedSdk][@"SDKPath"];
}

- (NSString *)simulatedSdkShortVersion
{
  return [self sdkInfoForSimulatedSdk][@"Version"];
}

- (NSString *)simulatedSdkName
{
  if ([_buildSettings[Xcode_SDK_NAME] hasPrefix:@"macosx"]) {
    return _buildSettings[Xcode_SDK_NAME];
  }
  return [self sdkInfoForSimulatedSdk][@"CanonicalName"];
}

- (NSDictionary *)sdkInfoForSimulatedSdk
{
  NSString *platform = _buildSettings[Xcode_PLATFORM_NAME];
  if (!platform) {
    platform = [[[_buildSettings[Xcode_PLATFORM_DIR] lastPathComponent] stringByDeletingPathExtension] lowercaseString];
  }
  NSAssert([platform isEqualToString:@"iphonesimulator"] || [platform isEqualToString:@"macosx"] || [platform isEqualToString:@"appletvsimulator"], @"Platform '%@' is not yet supported.", platform);
  NSString *sdkVersion = [self simulatedSdkVersion];
  NSDictionary *sdkInfo = [SimulatorInfo _sdkInfoForPlatform:platform sdkVersion:sdkVersion];
  NSAssert(sdkInfo != nil, @"Unable to find SDK for platform %@ and sdk version %@. Available roots: %@", platform, sdkVersion, [SimulatorInfo _sdkNames]);
  return sdkInfo;
}

- (SimRuntime *)simulatedRuntime
{
  NSString *path = [self sdkInfoForSimulatedSdk][@"SDKPath"];
  return [self _runtimeWithSDKPath:path];
}

- (SimDevice *)simulatedDevice
{
  if (!_simulatedDevice) {
    SimRuntime *runtime = [self simulatedRuntime];
    if (_deviceUDID) {
      return [self deviceWithUDID:_deviceUDID];
    } else {
      NSDictionary *supportedDeviceTypesByAlias;
      if (ToolchainIsXcode81OrBetter()) {
        supportedDeviceTypesByAlias = [_simulatedServiceContext supportedDeviceTypesByAlias];
      } else {
        supportedDeviceTypesByAlias = [SimDeviceType supportedDeviceTypesByAlias];
      }
      SimDeviceType *deviceType = supportedDeviceTypesByAlias[[self simulatedDeviceInfoName]];
      NSAssert(deviceType != nil, @"Unable to find SimDeviceType for the device with name \"%@\". Available device names: %@", [self simulatedDeviceInfoName], [supportedDeviceTypesByAlias allKeys]);
      for (SimDevice *device in [_simulatedDeviceSet availableDevices]) {
        if ([device.deviceType isEqual:deviceType] &&
            [device.runtime isEqual:runtime]) {
          _simulatedDevice = device;
          break;
        }
      }
    }

    NSAssert(_simulatedDevice != nil, @"Simulator with name \"%@\" doesn't have configuration with sdk version \"%@\". Available configurations: %@.", [self simulatedDeviceInfoName], runtime.versionString, [self _availableDeviceConfigurationsInHumanReadableFormat]);
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
  NSMutableArray *librariesToInsert = [NSMutableArray array];
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
  [librariesToInsert addObject:ideBundleInjectionLibPath];

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

#pragma mark - External Helpers

- (NSArray *)availableDevices
{
  if (ToolchainIsXcode81OrBetter()) {
    return [[_simulatedServiceContext supportedDeviceTypes] valueForKeyPath:@"name"];
  } else {
    return [[SimDeviceType supportedDeviceTypes] valueForKeyPath:@"name"];
  }
}

- (BOOL)isDeviceAvailableWithAlias:(NSString *)deviceName
{
  if (ToolchainIsXcode81OrBetter()) {
    return [_simulatedServiceContext supportedDeviceTypesByAlias][deviceName] != nil;
  } else {
    return [SimDeviceType supportedDeviceTypesByAlias][deviceName] != nil;
  }
}

- (SimDevice *)deviceWithUDID:(NSUUID *)deviceUDID
{
  for (SimDevice *device in [_simulatedDeviceSet availableDevices]) {
    if ([device.UDID isEqual:deviceUDID]) {
      return device;
    }
  }
  return nil;
}

- (NSString *)deviceNameForAlias:(NSString *)deviceAlias
{
  if (ToolchainIsXcode81OrBetter()) {
    return [[_simulatedServiceContext supportedDeviceTypesByAlias][deviceAlias] name];
  } else {
    return [[SimDeviceType supportedDeviceTypesByAlias][deviceAlias] name];
  }
}

- (BOOL)isSdkVersion:(NSString *)sdkVersion supportedByDevice:(NSString *)deviceName
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

- (NSArray *)sdksSupportedByDevice:(NSString *)deviceName
{
  NSArray *runtimes = [self _runtimesSupportedByDevice:deviceName];
  return [runtimes valueForKeyPath:@"versionString"];
}

#pragma mark -
#pragma mark Helpers

- (NSMutableArray *)_runtimesSupportedByDevice:(NSString *)deviceName
{
  NSMutableArray *deviceSupportedRuntimes = [NSMutableArray array];
  NSDictionary *supportedDeviceTypesByAlias;
  NSArray *systemSupportedRuntimes;
  if (ToolchainIsXcode81OrBetter()) {
    supportedDeviceTypesByAlias = [_simulatedServiceContext supportedDeviceTypesByAlias];
    systemSupportedRuntimes = [_simulatedServiceContext supportedRuntimes];
  } else {
    supportedDeviceTypesByAlias = [SimDeviceType supportedDeviceTypesByAlias];
    systemSupportedRuntimes = [SimRuntime supportedRuntimes];
  }
  SimDeviceType *deviceType = supportedDeviceTypesByAlias[deviceName];
  NSAssert(deviceType != nil, @"Unable to find SimDeviceType for the device with name \"%@\". Available device names: %@", deviceName, [supportedDeviceTypesByAlias allKeys]);
  for (SimRuntime *runtime in systemSupportedRuntimes) {
    if ([runtime supportsDeviceType:deviceType]) {
      [deviceSupportedRuntimes addObject:runtime];
    }
  }
  return deviceSupportedRuntimes;
}

- (NSArray *)_availableDeviceConfigurationsInHumanReadableFormat
{
  NSMutableArray *configs = [NSMutableArray array];
  for (SimDevice *device in [_simulatedDeviceSet availableDevices]) {
    [configs addObject:[NSString stringWithFormat:@"%@: %@", device.name, device.runtime.name]];
  }
  return configs;
}

#pragma mark -
#pragma mark Caching methods

static NSMutableDictionary *__platformInfo = nil;
static NSMutableDictionary *__platformInfoByBundleID = nil;
static NSMutableDictionary *__platformInfoByPath = nil;
static NSMutableDictionary *__deviceTypesInfo = nil;
static NSMutableDictionary *__deviceTypesInfoByBundleID = nil;
static NSMutableDictionary *__deviceTypesInfoByPath = nil;
static NSMutableDictionary *__runtimesInfo = nil;
static NSMutableDictionary *__runtimesInfoByBundleID = nil;
static NSMutableDictionary *__runtimesInfoByPath = nil;
static NSMutableDictionary *__sdkInfo = nil;
static NSMutableDictionary *__sdkInfoByPath = nil;

// This method will go through the folder hierarchy of the simulators to collect information
// about the platforms, devices, runtimes and SDKs.
+ (void)_warmUpSimulatorsInfo
{
  __platformInfo = [[NSMutableDictionary alloc] init];
  __platformInfoByBundleID = [[NSMutableDictionary alloc] init];
  __platformInfoByPath = [[NSMutableDictionary alloc] init];

  __deviceTypesInfo = [[NSMutableDictionary alloc] init];
  __deviceTypesInfoByBundleID = [[NSMutableDictionary alloc] init];
  __deviceTypesInfoByPath = [[NSMutableDictionary alloc] init];

  __runtimesInfo = [[NSMutableDictionary alloc] init];
  __runtimesInfoByBundleID = [[NSMutableDictionary alloc] init];
  __runtimesInfoByPath = [[NSMutableDictionary alloc] init];

  __sdkInfo = [[NSMutableDictionary alloc] init];
  __sdkInfoByPath = [[NSMutableDictionary alloc] init];

  [self _populatePlatformWithPath:IOSSimulatorPlatformPath()];
  [self _populatePlatformWithPath:AppleTVSimulatorPlatformPath()];
  [self _populatePlatformWithPath:WatchSimulatorPlatformPath()];
}

+ (void)_populatePlatformWithPath:(NSString *)platformPath
{
  NSString *infoPlistPath = [platformPath stringByAppendingPathComponent:@"Info.plist"];
  NSMutableDictionary * infoPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:infoPlistPath];
  if (infoPlist == nil) {
    // skip if the platform doesn't exist.
    return;
  }

  infoPlist[@"PlatformPath"] = platformPath;

  NSString *simulatedDeviceTypesPath = [platformPath stringByAppendingPathComponent:@"Developer/Library/CoreSimulator/Profiles/DeviceTypes"];
  NSArray *simulatedDevices = [self _populateSimulatedDeviceInfo:simulatedDeviceTypesPath platformName:infoPlist[@"Name"]];
  infoPlist[@"SimulatedDevices"] = simulatedDevices;

  NSString *runtimesPath = [platformPath stringByAppendingPathComponent:@"Developer/Library/CoreSimulator/Profiles/Runtimes"];
  NSArray *runtimes = [self _populateRuntimesInfo:runtimesPath platformName:infoPlist[@"Name"]];
  infoPlist[@"Runtimes"] = runtimes;

  NSString *sdkPath = [platformPath stringByAppendingPathComponent:@"Developer/SDKs"];
  NSArray *sdks = [self _populateSKSsInfo:sdkPath platformName:infoPlist[@"Name"]];
  infoPlist[@"SDKs"] = sdks;

  __platformInfo[infoPlist[@"Name"]] = infoPlist;
  __platformInfoByBundleID[infoPlist[@"CFBundleIdentifier"]] = infoPlist;
  __platformInfoByPath[platformPath] = infoPlist;
}

+ (NSArray *)_populateSimulatedDeviceInfo:(NSString *)deviceTypesPath platformName:(NSString *)platformName
{
  NSMutableArray *result = [NSMutableArray array];

  NSArray * contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:deviceTypesPath error:NULL];
  for (NSString * path in contents) {
    NSString * subpath = [deviceTypesPath stringByAppendingPathComponent:path];
    NSString * infoPlistPath = [subpath stringByAppendingPathComponent:@"Contents/Info.plist"];
    NSMutableDictionary * infoPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:infoPlistPath];
    NSString * capabilitiesPath = [subpath stringByAppendingPathComponent:@"Contents/Resources/capabilities.plist"];
    NSDictionary * capabilities = [[NSDictionary alloc] initWithContentsOfFile:capabilitiesPath];
    infoPlist[@"Capabilities"] = capabilities;
    NSString * profilePath = [subpath stringByAppendingPathComponent:@"Contents/Resources/profile.plist"];
    NSDictionary * profile = [[NSDictionary alloc] initWithContentsOfFile:profilePath];
    infoPlist[@"Profile"] = profile;
    infoPlist[@"DeviceTypePath"] = subpath;
    infoPlist[@"PlatformName"] = platformName;

    __deviceTypesInfo[infoPlist[@"CFBundleName"]] = infoPlist;
    __deviceTypesInfoByBundleID[infoPlist[@"CFBundleIdentifier"]] = infoPlist;
    __deviceTypesInfoByPath[subpath] = infoPlist;

    [result addObject:infoPlist];
  }

  return result;
}

+ (NSArray *)_populateRuntimesInfo:(NSString *)deviceTypesPath platformName:(NSString *)platformName
{
  NSMutableArray *result = [NSMutableArray array];

  NSArray * contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:deviceTypesPath error:NULL];
  for (NSString * path in contents) {
    NSString * subpath = [deviceTypesPath stringByAppendingPathComponent:path];
    NSString * infoPlistPath = [subpath stringByAppendingPathComponent:@"Contents/Info.plist"];
    NSMutableDictionary * infoPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:infoPlistPath];
    NSString * defaultDevicesPath = [subpath stringByAppendingPathComponent:@"Contents/Resources/default_devices.plist"];
    NSDictionary * defaultDevices = [[NSDictionary alloc] initWithContentsOfFile:defaultDevicesPath];
    infoPlist[@"DefaultDevices"] = defaultDevices;
    NSString * profilePath = [subpath stringByAppendingPathComponent:@"Contents/Resources/profile.plist"];
    NSDictionary * profile = [[NSDictionary alloc] initWithContentsOfFile:profilePath];
    infoPlist[@"Profile"] = profile;
    infoPlist[@"RuntimePath"] = subpath;
    infoPlist[@"PlatformName"] = platformName;

    __runtimesInfo[infoPlist[@"CFBundleName"]] = infoPlist;
    __runtimesInfoByBundleID[infoPlist[@"CFBundleIdentifier"]] = infoPlist;
    __runtimesInfoByPath[subpath] = infoPlist;

    [result addObject:infoPlist];
  }

  return result;
}

+ (NSArray *)_populateSKSsInfo:(NSString *)sdkPath platformName:(NSString *)platformName
{
  NSMutableArray *result = [NSMutableArray array];

  NSArray * contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:sdkPath error:NULL];
  for (NSString * path in contents) {
    NSString * subpath = [sdkPath stringByAppendingPathComponent:path];
    NSString * infoPlistPath = [subpath stringByAppendingPathComponent:@"SDKSettings.plist"];
    NSMutableDictionary * infoPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:infoPlistPath];
    infoPlist[@"SDKPath"] = subpath;
    infoPlist[@"PlatformName"] = platformName;

    __sdkInfo[infoPlist[@"CanonicalName"]] = infoPlist;
    __sdkInfoByPath[subpath] = infoPlist;

    [result addObject:infoPlist];
  }

  return result;
}

+ (NSArray *)_sdkNames
{
  return [__sdkInfo allKeys];
}

- (SimRuntime *)_runtimeWithSDKPath:(NSString *)path
{
  path = [path stringByResolvingSymlinksInPath];
  NSDictionary *sdkInfo = __sdkInfoByPath[path];
  NSString *platformName = sdkInfo[@"PlatformName"];
  NSString *platformVersion = sdkInfo[@"Version"];
  NSDictionary *platformInfo = __platformInfo[platformName];
  NSString *platformPath = platformInfo[@"PlatformPath"];

  NSArray *runTimeArray;
  if (ToolchainIsXcode81OrBetter()) {
    runTimeArray = [_simulatedServiceContext supportedRuntimes];
  } else {
    runTimeArray = [SimRuntime supportedRuntimes];
  }
  for (SimRuntime* runTime in runTimeArray) {
    if ([[runTime platformPath] isEqualToString:platformPath] &&
        [[runTime versionString] isEqualToString:platformVersion]) {
      return runTime;
    }
  }
  return nil;
}

+ (NSDictionary *)_sdkInfoForPlatform:(NSString *)platform sdkVersion:(NSString *)sdkVersion
{
  NSString *canonicalName = [platform stringByAppendingString:sdkVersion];
  return __sdkInfo[canonicalName];
}

@end
