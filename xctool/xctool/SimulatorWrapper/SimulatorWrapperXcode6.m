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

#import "SimDevice.h"
#import "SimDeviceSet.h"
#import "SimDeviceType.h"
#import "SimRuntime.h"
#import "SimulatorInfoXcode6.h"
#import "SimulatorLauncher.h"
#import "SimulatorWrapperInternal.h"
#import "XCToolUtil.h"

@implementation SimulatorWrapperXcode6

#pragma mark -
#pragma mark Internal

+ (DTiPhoneSimulatorSessionConfig *)sessionConfigForRunningTestsOnSimulator:(SimulatorInfoXcode6 *)simInfo
                                                      applicationLaunchArgs:(NSArray *)launchArgs
                                               applicationLaunchEnvironment:(NSDictionary *)launchEnvironment
                                                                 outputPath:(NSString *)outputPath
{
  NSDictionary *deviceEnvironment = [[simInfo simulatedDevice] environment] ?: @{};
  NSMutableDictionary *launchEnvironmentEdited = [deviceEnvironment mutableCopy];
  [launchEnvironmentEdited addEntriesFromDictionary:launchEnvironment];
  if (deviceEnvironment[@"TMPDIR"]) {
    launchEnvironmentEdited[@"TMPDIR"] = deviceEnvironment[@"TMPDIR"];
  }

  DTiPhoneSimulatorSessionConfig *sessionConfig = [SimulatorWrapper sessionConfigForRunningTestsOnSimulator:simInfo applicationLaunchArgs:launchArgs applicationLaunchEnvironment:launchEnvironmentEdited outputPath:outputPath];

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
    if (error) {
      *error = [NSError errorWithDomain:@"com.apple.iOSSimulator"
                                   code:0
                               userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
    }
    return NO;
  }

  NSURL *iOSSimulatorURL = [NSURL fileURLWithPath:[NSString pathWithComponents:@[XcodeDeveloperDirPath(), @"Applications/iOS Simulator.app"]]];
  NSDictionary *configuration = @{NSWorkspaceLaunchConfigurationArguments: @[@"-CurrentDeviceUDID", [[[simInfo simulatedDevice] UDID] UUIDString]]};
  NSError *launchError = nil;
  NSRunningApplication *app = [[NSWorkspace sharedWorkspace] launchApplicationAtURL:iOSSimulatorURL
                                                                            options:NSWorkspaceLaunchDefault
                                                                      configuration:configuration
                                                                              error:&launchError];
  if (!app) {
    NSString *errorDesc = [NSString stringWithFormat: @"iOS Simulator app wasn't launched at path \"%@\" with configuration: %@. Error: %@", [iOSSimulatorURL path], configuration, launchError];
    if (error) {
      *error = [NSError errorWithDomain:@"com.apple.iOSSimulator"
                                   code:0
                               userInfo:@{NSLocalizedDescriptionKey: errorDesc}];
    }
    return NO;
  }

  int attempts = 30;
  while ([[simInfo simulatedDevice] state] != SimDeviceStateBooted && attempts > 0) {
    [NSThread sleepForTimeInterval:0.1];
    --attempts;
  }

  return attempts > 0;
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


/*
 *  In order to make xctool linkable in Xcode 5 we need to provide stub implementations
 *  of iOS simulator private classes used in xctool and defined in
 *  the CoreSimulator framework (introduced in Xcode 6).
 *
 *  But xctool, when built with Xcode 5 but running in Xcode 6, should use the
 *  implementations of those classes from CoreSimulator framework rather than the stub
 *  implementations. That is why we need to create stubs and forward all selector
 *  invocations to the original implementation of the class if it exists.
 */

#if XCODE_VERSION < 0600

@implementation SimDeviceSetStub
+ (id)forwardingTargetForSelector:(SEL)aSelector
{
  Class class = NSClassFromString(@"SimDeviceSet");
  NSAssert(class, @"Class SimDeviceType wasn't found though it was expected to exist.");
  return class;
}
@end

@implementation SimDeviceTypeStub
+ (id)forwardingTargetForSelector:(SEL)aSelector
{
  Class class = NSClassFromString(@"SimDeviceType");
  NSAssert(class, @"Class SimDeviceType wasn't found though it was expected to exist.");
  return class;
}
@end

@implementation SimRuntimeStub
+ (id)forwardingTargetForSelector:(SEL)aSelector
{
  Class class = NSClassFromString(@"SimRuntime");
  NSAssert(class, @"Class SimRuntime wasn't found though it was expected to exist.");
  return class;
}
@end

#else

/*
 *  If xctool is built using Xcode 6 then we just need to provide empty implementations
 *  of the stubs because they simply inherit original CoreSimulator private classes in
 *  that case.
 */

@implementation SimDeviceSetStub
@end

@implementation SimDeviceTypeStub
@end

@implementation SimRuntimeStub
@end

#endif
