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

#import <Foundation/Foundation.h>

#import "SimulatorInfoXcode5.h"
#import "SimulatorInfoXcode6.h"

@implementation SimulatorInfo

+ (BOOL)isXcode6OrHigher
{
  return NSClassFromString(@"SimDevice") != nil;
}

+ (Class)classCurrentVersionOfXcode
{
  if ([self isXcode6OrHigher]) {
    return [SimulatorInfoXcode6 class];
  } else {
    return [SimulatorInfoXcode5 class];
  }
}

+ (SimulatorInfo *)infoForCurrentVersionOfXcode
{
  return [[[[self classCurrentVersionOfXcode] alloc] init] autorelease];
}

#pragma mark -
#pragma mark Redirect to available class

+ (NSArray *)availableDevices
{
  return [[self classCurrentVersionOfXcode] availableDevices];
}

+ (BOOL)isDeviceAvailableWithAlias:(NSString *)deviceName
{
  return [[self classCurrentVersionOfXcode] isDeviceAvailableWithAlias:deviceName];
}

+ (BOOL)isSdkVersion:(NSString *)sdkVersion supportedByDevice:(NSString *)deviceName
{
  return [[self classCurrentVersionOfXcode] isSdkVersion:sdkVersion supportedByDevice:deviceName];
}

+ (NSString *)sdkVersionForOSVersion:(NSString *)osVersion
{
  return [[self classCurrentVersionOfXcode] sdkVersionForOSVersion:osVersion];
}

+ (NSArray *)availableSdkVersions
{
  return [[self classCurrentVersionOfXcode] availableSdkVersions];
}

+ (NSArray *)sdksSupportedByDevice:(NSString *)deviceName
{
  return [[self classCurrentVersionOfXcode] sdksSupportedByDevice:deviceName];
}

+ (cpu_type_t)cpuTypeForDevice:(NSString *)deviceName
{
  return [[self classCurrentVersionOfXcode] cpuTypeForDevice:deviceName];
}

+ (NSString *)baseVersionForSDKShortVersion:(NSString *)shortVersionString
{
  return [[self classCurrentVersionOfXcode] baseVersionForSDKShortVersion:shortVersionString];
}

#pragma mark -
#pragma mark Should be implemented in subclass

- (NSString *)simulatedArchitecture {assert(NO);};
- (NSNumber *)simulatedDeviceFamily {assert(NO);};
- (NSString *)simulatedDeviceInfoName {assert(NO);};
- (NSString *)simulatedSdkVersion {assert(NO);};
- (NSString *)simulatedSdkShortVersion {assert(NO);};
- (NSString *)simulatedSdkRootPath {assert(NO);};
- (DTiPhoneSimulatorSystemRoot *)systemRootForSimulatedSdk{assert(NO);};;
- (NSDictionary *)simulatorLaunchEnvironment {assert(NO);};;

@end
