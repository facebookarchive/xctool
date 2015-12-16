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

#import "SimulatorWrapperXcode6.h"

#import <AppKit/AppKit.h>

#import "SimDevice.h"
#import "SimDeviceSet.h"
#import "SimDeviceType.h"
#import "SimRuntime.h"
#import "SimulatorUtils.h"
#import "XCToolUtil.h"

@implementation SimulatorWrapperXcode6

#pragma mark -
#pragma mark Helpers

+ (BOOL)prepareSimulator:(SimDevice *)device
    newSimulatorInstance:(BOOL)newSimulatorInstance
               reporters:(NSArray *)reporters
                   error:(NSString **)error
{
  if (!device.available) {
    if (error) {
      *error = [NSString stringWithFormat: @"Simulator '%@' is not available", device.name];
    }
    return NO;
  }

  NSURL *iOSSimulatorURL = nil;
  if (ToolchainIsXcode7OrBetter()) {
    iOSSimulatorURL = [NSURL fileURLWithPath:[NSString pathWithComponents:@[XcodeDeveloperDirPath(), @"Applications/Simulator.app"]]];
  } else {
    iOSSimulatorURL = [NSURL fileURLWithPath:[NSString pathWithComponents:@[XcodeDeveloperDirPath(), @"Applications/iOS Simulator.app"]]];
  }
  NSDictionary *configuration = @{NSWorkspaceLaunchConfigurationArguments: @[@"-CurrentDeviceUDID", [device.UDID UUIDString]]};
  NSError *launchError = nil;
  
  NSWorkspaceLaunchOptions launchOptions = NSWorkspaceLaunchAsync | NSWorkspaceLaunchWithoutActivation | NSWorkspaceLaunchAndHide;
  if (newSimulatorInstance) {
    launchOptions = launchOptions | NSWorkspaceLaunchNewInstance;
  }

  NSRunningApplication *app = [[NSWorkspace sharedWorkspace] launchApplicationAtURL:iOSSimulatorURL
                                                                            options:launchOptions
                                                                      configuration:configuration
                                                                              error:&launchError];
  if (!app) {
    if (error) {
      *error = [NSString stringWithFormat: @"iOS Simulator app wasn't launched at path \"%@\" with configuration: %@. Error: %@", [iOSSimulatorURL path], configuration, launchError];
    }
    return NO;
  }

  int attempts = 30;
  while (device.state != SimDeviceStateBooted && attempts > 0) {
    [NSThread sleepForTimeInterval:0.1];
    --attempts;
  }

  if (attempts > 0) {
    return YES;
  }

  if (error) {
    *error = @"Timed out while waiting simulator to boot.";
  }
  return NO;
}

#pragma mark -
#pragma mark Main Methods

+ (BOOL)uninstallTestHostBundleID:(NSString *)testHostBundleID
                           device:(SimDevice *)device
                        reporters:(NSArray *)reporters
                            error:(NSString **)error
{
  __block BOOL installed = YES;
  RunSimulatorBlockWithTimeout(^{
    installed = [device applicationIsInstalled:testHostBundleID type:nil error:nil];
  });
  if (!installed) {
    return YES;
  }

  __block NSError *localError = nil;
  __block BOOL uninstalled = NO;
  if (!RunSimulatorBlockWithTimeout(^{
    uninstalled = [device uninstallApplication:testHostBundleID
                                   withOptions:nil
                                         error:&localError];
  })) {
    localError = [NSError errorWithDomain:@"com.facebook.xctool.sim.uninstall.timeout"
                                     code:0
                                 userInfo:@{
      NSLocalizedDescriptionKey: @"Timed out.",
    }];
  }

  if (!uninstalled) {
    *error = [NSString stringWithFormat:
              @"Failed to uninstall the test host app '%@': %@",
              testHostBundleID, localError.localizedDescription ?: @"Failed for unknown reason."];
  }
  return uninstalled;
}

+ (BOOL)installTestHostBundleID:(NSString *)testHostBundleID
                 fromBundlePath:(NSString *)testHostBundlePath
                         device:(SimDevice *)device
                      reporters:(NSArray *)reporters
                          error:(NSString **)error
{
  __block NSError *localError = nil;
  __block BOOL installed = NO;
  if (!RunSimulatorBlockWithTimeout(^{
    installed = [device installApplication:[NSURL fileURLWithPath:testHostBundlePath]
                               withOptions:@{@"CFBundleIdentifier": testHostBundleID}
                                     error:&localError];
  })) {
    localError = [NSError errorWithDomain:@"com.facebook.xctool.sim.install.timeout"
                                     code:0
                                 userInfo:@{
      NSLocalizedDescriptionKey: @"Timed out.",
    }];
  }

  if (!installed) {
    *error = [NSString stringWithFormat:
              @"Failed to install the test host app '%@': %@",
              testHostBundleID, localError.localizedDescription ?: @"Failed for unknown reason."];

  }
  return installed;
}

@end
