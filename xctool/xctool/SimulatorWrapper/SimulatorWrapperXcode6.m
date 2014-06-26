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

#import "SimulatorWrapperXcode6.h"
#import "SimulatorWrapperInternal.h"

#import "SimulatorInfoXcode6.h"
#import "SimulatorLauncher.h"
#import "SimDevice.h"
#import "SimDeviceSet.h"
#import "SimDeviceType.h"
#import "SimRuntime.h"

@implementation SimulatorWrapperXcode6

#pragma mark -
#pragma mark Internal

+ (DTiPhoneSimulatorSessionConfig *)sessionConfigForRunningTestsOnSimulator:(SimulatorInfoXcode6 *)simInfo
                                                      applicationLaunchArgs:(NSArray *)launchArgs
                                               applicationLaunchEnvironment:(NSDictionary *)launchEnvironment
                                                                 outputPath:(NSString *)outputPath
{
  DTiPhoneSimulatorSessionConfig *sessionConfig = [SimulatorWrapper sessionConfigForRunningTestsOnSimulator:simInfo applicationLaunchArgs:launchArgs applicationLaunchEnvironment:launchEnvironment outputPath:outputPath];

  [sessionConfig setDevice:[simInfo simulatedDevice]];
  [sessionConfig setRuntime:[simInfo simulatedRuntime]];

  return sessionConfig;
}

#pragma mark -
#pragma mark Helpers

+ (BOOL)prepareSimulatorWithSimulatorInfo:(SimulatorInfoXcode6 *)simInfo
                                    error:(NSError **)error
{
  if (![simInfo simulatedDevice].available) {
    NSString *errorDesc = [NSString stringWithFormat: @"Simulator '%@' is not available", [simInfo simulatedDevice].name];
    *error = [NSError errorWithDomain:@"com.apple.iOSSimulator"
                                 code:0
                             userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
    return NO;
  }
  
  if ([simInfo simulatedDevice].state == SimDeviceStateBooted) {
    return YES;
  }

  DTiPhoneSimulatorApplicationSpecifier *appSpec = [DTiPhoneSimulatorApplicationSpecifier specifierWithApplicationBundleIdentifier:@"com.apple.unknown"];
  DTiPhoneSimulatorSystemRoot *systemRoot = [simInfo systemRootForSimulatedSdk];

  DTiPhoneSimulatorSessionConfig *sessionConfig = [[[DTiPhoneSimulatorSessionConfig alloc] init] autorelease];
  [sessionConfig setApplicationToSimulateOnStart:appSpec];
  [sessionConfig setDevice:[simInfo simulatedDevice]];
  [sessionConfig setRuntime:[simInfo simulatedRuntime]];
  [sessionConfig setSimulatedApplicationLaunchArgs:@[]];
  [sessionConfig setSimulatedApplicationLaunchEnvironment:@{}];
  [sessionConfig setSimulatedApplicationShouldWaitForDebugger:NO];
  [sessionConfig setSimulatedArchitecture:[simInfo simulatedArchitecture]];
  [sessionConfig setSimulatedDeviceFamily:[simInfo simulatedDeviceFamily]];
  [sessionConfig setSimulatedDeviceInfoName:[simInfo simulatedDeviceInfoName]];
  [sessionConfig setSimulatedSystemRoot:systemRoot];

  SimulatorLauncher *launcher = [[[SimulatorLauncher alloc] initWithSessionConfig:sessionConfig
                                                                       deviceName:[simInfo simulatedDeviceInfoName]] autorelease];

  BOOL simStartedSuccessfully = [launcher launchAndWaitForStart] || [simInfo simulatedDevice].state == SimDeviceStateBooted;
  if (!simStartedSuccessfully) {
    *error = launcher.launchError;
  }
  
  return simStartedSuccessfully;
}

#pragma mark -
#pragma mark Main Methods

+ (BOOL)uninstallTestHostBundleID:(NSString *)testHostBundleID
                    simulatorInfo:(SimulatorInfoXcode6 *)simInfo
                        reporters:(NSArray *)reporters
                            error:(NSString **)error
{
  NSError *localError = nil;
  SimDevice *device = [simInfo simulatedDevice];

  if (![self prepareSimulatorWithSimulatorInfo:simInfo error:&localError]) {
    *error = [NSString stringWithFormat:
              @"Simulator '%@' was not prepared: %@",
              [simInfo simulatedDevice].name, localError.localizedDescription ?: @"Failed for unknown reason."];
    return NO;
  }

  BOOL uninstalled = ![device applicationIsInstalled:testHostBundleID type:nil error:&localError];
  if (!uninstalled) {
    uninstalled = [device uninstallApplication:testHostBundleID
                                   withOptions:nil
                                         error:&localError];
  }

  if (!uninstalled) {
    *error = [NSString stringWithFormat:
              @"Failed to uninstall the test host app '%@' "
              @"before running tests: %@",
              testHostBundleID, localError.localizedDescription ?: @"Failed for unknown reason."];
  }
  return uninstalled;
}

+ (BOOL)installTestHostBundleID:(NSString *)testHostBundleID
                 fromBundlePath:(NSString *)testHostBundlePath
                  simulatorInfo:(SimulatorInfoXcode6 *)simInfo
                      reporters:(NSArray *)reporters
                          error:(NSString **)error
{
  NSError *localError = nil;
  SimDevice *device = [simInfo simulatedDevice];
  NSURL *appURL = [NSURL fileURLWithPath:testHostBundlePath];

  if (![self prepareSimulatorWithSimulatorInfo:simInfo error:&localError]) {
    *error = [NSString stringWithFormat:
              @"Simulator '%@' was not prepared: %@",
              [simInfo simulatedDevice].name, localError.localizedDescription ?: @"Failed for unknown reason."];
    return NO;
  }

  BOOL installed = [device installApplication:appURL
                                  withOptions:@{@"CFBundleIdentifier": testHostBundleID}
                                        error:&localError];

  if (!installed) {
    *error = [NSString stringWithFormat:
              @"Failed to install the test host app '%@': %@",
              testHostBundleID, localError.localizedDescription ?: @"Failed for unknown reason."];

  }
  return installed;
}

@end


#if XCODE_VERSION < 0600
@implementation SimDeviceSet
@end
@implementation SimDeviceType
@end
@implementation SimRuntime
@end
#endif
