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

@class DTiPhoneSimulatorSystemRoot, SimDevice, SimRuntime;

@interface SimulatorInfo : NSObject <NSCopying>

@property (nonatomic, copy) NSDictionary *buildSettings;


/*
 * `SimulatorInfo` needs to be prepared before being used.
 *
 * This method should be called on the main thread due to 
 * Xcode internals expectations. Doing it while performing
 * xctool actions may result in a deadlock so this preparation
 * should be done as early as possible.
 */
+ (void)prepare;

- (void)setCpuType:(cpu_type_t)cpuType;
- (void)setDeviceName:(NSString *)deviceName;
- (void)setOSVersion:(NSString *)OSVersion;
- (void)setDeviceUDID:(NSUUID *)deviceUDID;

- (cpu_type_t)simulatedCpuType;
- (NSString *)simulatedArchitecture;
- (NSNumber *)simulatedDeviceFamily;
- (NSString *)simulatedDeviceInfoName;

- (SimDevice *)simulatedDevice;
- (SimRuntime *)simulatedRuntime;

- (NSString *)simulatedSdkVersion;
- (NSString *)simulatedSdkShortVersion;
- (NSString *)simulatedSdkRootPath;
- (NSString *)simulatedSdkName;
- (NSNumber *)launchTimeout;

- (DTiPhoneSimulatorSystemRoot *)systemRootForSimulatedSdk;

- (NSMutableDictionary *)simulatorLaunchEnvironment;

- (NSString *)testHostPath;
- (NSString *)productBundlePath;

+ (NSArray *)availableDevices;
+ (NSString *)deviceNameForAlias:(NSString *)deviceAlias;
+ (BOOL)isDeviceAvailableWithAlias:(NSString *)deviceName;
+ (BOOL)isSdkVersion:(NSString *)sdkVersion supportedByDevice:(NSString *)deviceName;
+ (NSArray *)availableSdkVersions;
+ (NSArray *)sdksSupportedByDevice:(NSString *)deviceName;
+ (cpu_type_t)cpuTypeForDevice:(NSString *)deviceName;
+ (SimDevice *)deviceWithUDID:(NSUUID *)deviceUDID;

@end
