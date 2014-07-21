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

#import "SimulatorWrapperXcode5.h"
#import "SimulatorWrapperInternal.h"

#import "SimulatorInfo.h"
#import "SimulatorLauncher.h"
#import "XCToolUtil.h"

@implementation SimulatorWrapperXcode5

#pragma mark -
#pragma mark Helpers

+ (BOOL)runMobileInstallationHelperWithArguments:(NSArray *)arguments simulatorInfo:(SimulatorInfo *)simInfo error:(NSError **)error
{
  DTiPhoneSimulatorSystemRoot *systemRoot = [simInfo systemRootForSimulatedSdk];

  DTiPhoneSimulatorApplicationSpecifier *appSpec = [DTiPhoneSimulatorApplicationSpecifier specifierWithApplicationPath:
                                                    [XCToolLibExecPath() stringByAppendingPathComponent:@"mobile-installation-helper.app"]];
  DTiPhoneSimulatorSessionConfig *sessionConfig = [[DTiPhoneSimulatorSessionConfig alloc] init];
  [sessionConfig setApplicationToSimulateOnStart:appSpec];
  [sessionConfig setSimulatedSystemRoot:systemRoot];
  [sessionConfig setSimulatedDeviceFamily:[simInfo simulatedDeviceFamily]];
  [sessionConfig setSimulatedApplicationShouldWaitForDebugger:NO];
  [sessionConfig setLocalizedClientName:@"xctool"];
  [sessionConfig setSimulatedApplicationLaunchArgs:arguments];
  [sessionConfig setSimulatedApplicationLaunchEnvironment:@{}];
  [sessionConfig setSimulatedDeviceInfoName:[simInfo simulatedDeviceInfoName]];

  SimulatorLauncher *launcher = [[SimulatorLauncher alloc] initWithSessionConfig:sessionConfig
                                                                       deviceName:[simInfo simulatedDeviceInfoName]];
  launcher.launchTimeout = [simInfo launchTimeout];

  BOOL simStartedSuccessfully = [launcher launchAndWaitForExit];
  if (!simStartedSuccessfully && error) {
    *error = launcher.launchError;
  }

  return simStartedSuccessfully;
}

#pragma mark -
#pragma mark Main Methods

+ (BOOL)uninstallTestHostBundleID:(NSString *)testHostBundleID
                    simulatorInfo:(SimulatorInfo *)simInfo
                        reporters:(NSArray *)reporters
                            error:(NSString **)error
{
  NSError *localError = nil;
  BOOL uninstalled = [self runMobileInstallationHelperWithArguments:@[@"uninstall", testHostBundleID]
                                                      simulatorInfo:simInfo
                                                              error:&localError];
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
                  simulatorInfo:(SimulatorInfo *)simInfo
                      reporters:(NSArray *)reporters
                          error:(NSString **)error
{
  NSError *localError = nil;
  BOOL installed = [self runMobileInstallationHelperWithArguments:@[@"install", testHostBundlePath,]
                                                    simulatorInfo:simInfo
                                                            error:&localError];
  if (!installed) {
    *error = [NSString stringWithFormat:
              @"Failed to install the test host app '%@': %@",
              testHostBundleID, localError.localizedDescription ?: @"Failed for unknown reason."];
  }
  return installed;
}

@end
