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

@implementation SimulatorInfoXcode6
@synthesize buildSettings = _buildSettings;
@synthesize cpuType = _cpuType;
@synthesize deviceName = _deviceName;
@synthesize OSVersion = _OSVersion;

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

  DTiPhoneSimulatorSystemRoot *systemRoot = [DTiPhoneSimulatorSystemRoot rootWithSDKPath:_buildSettings[Xcode_SDKROOT]];
  if (!systemRoot) {
    return probableDeviceName;
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
  return [supportedDeviceTypes[0] name];
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
  NSMutableArray *runtimes = [[[[self class] _runtimesSupportedByDevice:[self simulatedDeviceInfoName]] mutableCopy] autorelease];
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
  DTiPhoneSimulatorSystemRoot *systemRoot = [DTiPhoneSimulatorSystemRoot rootWithSDKVersion:sdkVersion];
  if (systemRoot) {
    return systemRoot;
  }

  SimRuntime *runtime = [[self class] _runtimeForSdkVersion:sdkVersion];
  systemRoot = [DTiPhoneSimulatorSystemRoot rootWithSimRuntime:runtime];
  NSAssert(systemRoot != nil, @"Unable to instantiate DTiPhoneSimulatorSystemRoot for sdk version: %@. Available roots: %@", sdkVersion, [DTiPhoneSimulatorSystemRoot knownRoots]);
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
#pragma mark v6 methods

- (SimRuntime *)simulatedRuntime
{
  return [[self systemRootForSimulatedSdk] runtime];
}

- (SimDevice *)simulatedDevice
{
  SimRuntime *runtime = [self simulatedRuntime];
  SimDeviceType *deviceType = [SimDeviceType supportedDeviceTypesByAlias][[self simulatedDeviceInfoName]];
  for (SimDevice *device in [[SimDeviceSet defaultSet] availableDevices]) {
    if ([device.deviceType isEqual:deviceType] &&
        [device.runtime isEqual:runtime]) {
      return device;
    }
  }
  return nil;
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

#pragma mark -
#pragma mark - Helpers

+ (NSArray *)_runtimesSupportedByDevice:(NSString *)deviceName
{
  NSMutableArray *supportedRuntimes = [NSMutableArray array];
  SimDeviceType *deviceType = [SimDeviceType supportedDeviceTypesByAlias][deviceName];
  for (SimRuntime *runtime in [SimRuntime supportedRuntimes]) {
    if ([runtime supportsDeviceType:deviceType]) {
      [supportedRuntimes addObject:runtime];
    }
  }
  return supportedRuntimes;
}

+ (SimRuntime *)_runtimeForSdkVersion:(NSString *)sdkVersion
{
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
  DTiPhoneSimulatorSystemRoot *root = [DTiPhoneSimulatorSystemRoot rootWithSDKPath:sdkPath];
  return [root runtime];
}

@end
