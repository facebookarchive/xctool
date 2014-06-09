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

#import "SimulatorWrapper.h"

#import "DTiPhoneSimulatorRemoteClient.h"
#import "LineReader.h"
#import "ReportStatus.h"
#import "SimulatorInfo.h"
#import "SimulatorLauncher.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

@implementation SimulatorWrapper

+ (DTiPhoneSimulatorSessionConfig *)sessionConfigForRunningTestsOnSimulator:(SimulatorInfo *)simInfo
                                                      applicationLaunchArgs:(NSArray *)launchArgs
                                               applicationLaunchEnvironment:(NSDictionary *)launchEnvironment
                                                                 outputPath:(NSString *)outputPath
{
  // Sometimes the TEST_HOST will be wrapped in double quotes.
  NSString *testHostPath = [simInfo.buildSettings[Xcode_TEST_HOST] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
  NSString *testHostAppPath = [testHostPath stringByDeletingLastPathComponent];

  DTiPhoneSimulatorSystemRoot *systemRoot = [simInfo systemRootForSimulatedSdk];

  DTiPhoneSimulatorApplicationSpecifier *appSpec = [DTiPhoneSimulatorApplicationSpecifier specifierWithApplicationPath:testHostAppPath];

  DTiPhoneSimulatorSessionConfig *sessionConfig = [[[DTiPhoneSimulatorSessionConfig alloc] init] autorelease];
  [sessionConfig setApplicationToSimulateOnStart:appSpec];
  [sessionConfig setSimulatedSystemRoot:systemRoot];
  [sessionConfig setSimulatedDeviceFamily:[simInfo simulatedDeviceFamily]];
  [sessionConfig setSimulatedApplicationShouldWaitForDebugger:NO];
  [sessionConfig setSimulatedApplicationLaunchArgs:launchArgs];
  [sessionConfig setSimulatedDeviceInfoName:[simInfo simulatedDeviceInfoName]];
  [sessionConfig setSimulatedArchitecture:[simInfo simulatedArchitecture]];
  [sessionConfig setSimulatedApplicationLaunchEnvironment:launchEnvironment];
  [sessionConfig setSimulatedApplicationStdOutPath:outputPath];

  // Don't let anything from STDERR get in our stream.  Normally, once
  // otest-shim gets loaded, we don't have to worry about whatever is coming
  // over STDERR since the shim will redirect all output (including STDERR) into
  // JSON outout on STDOUT.
  //
  // But, even before otest-shim loads, there's a chance something else may spew
  // into STDERR.  This happened in --
  // https://github.com/facebook/xctool/issues/224#issuecomment-29288004
  [sessionConfig setSimulatedApplicationStdErrPath:@"/dev/null"];

  [sessionConfig setLocalizedClientName:@"xctool"];

  return sessionConfig;
}

+ (BOOL)runMobileInstallationHelperWithArguments:(NSArray *)arguments simulatorInfo:(SimulatorInfo *)simInfo error:(NSError **)error
{
  DTiPhoneSimulatorSystemRoot *systemRoot = [simInfo systemRootForSimulatedSdk];

  DTiPhoneSimulatorApplicationSpecifier *appSpec = [DTiPhoneSimulatorApplicationSpecifier specifierWithApplicationPath:
                                                    [XCToolLibExecPath() stringByAppendingPathComponent:@"mobile-installation-helper.app"]];
  DTiPhoneSimulatorSessionConfig *sessionConfig = [[[DTiPhoneSimulatorSessionConfig alloc] init] autorelease];
  [sessionConfig setApplicationToSimulateOnStart:appSpec];
  [sessionConfig setSimulatedSystemRoot:systemRoot];
  [sessionConfig setSimulatedDeviceFamily:[simInfo simulatedDeviceFamily]];
  [sessionConfig setSimulatedApplicationShouldWaitForDebugger:NO];
  [sessionConfig setLocalizedClientName:@"xctool"];
  [sessionConfig setSimulatedApplicationLaunchArgs:arguments];
  [sessionConfig setSimulatedApplicationLaunchEnvironment:@{}];
  [sessionConfig setSimulatedDeviceInfoName:[simInfo simulatedDeviceInfoName]];

  SimulatorLauncher *launcher = [[[SimulatorLauncher alloc] initWithSessionConfig:sessionConfig
                                                                       deviceName:[simInfo simulatedDeviceInfoName]] autorelease];

  BOOL simStartedSuccessfully = [launcher launchAndWaitForExit];
  if (!simStartedSuccessfully) {
    *error = launcher.launchError;
  }

  return simStartedSuccessfully;
}

/**
 * Use the DTiPhoneSimulatorRemoteClient framework to start the app in the sim,
 * inject otest-shim into the app as it starts, and feed line-by-line output to
 * the `feedOutputToBlock`.
 *
 * @param testHostAppPath Path to the .app
 * @param feedOutputToBlock The block is called once for every line of output
 * @param testsSucceeded If all tests ran and passed, this will be set to YES.
 * @param infraSucceeded If we succeeded in launching the app and running the
 *   the tests, this will be set to YES.  Note that this will be YES even if
 *   some tests failed.
 */
+ (void)runHostAppTests:(NSString *)testHostAppPath
          simulatorInfo:(SimulatorInfo *)simInfo
          appLaunchArgs:(NSArray *)launchArgs
   appLaunchEnvironment:(NSDictionary *)launchEnvironment
      feedOutputToBlock:(void (^)(NSString *))feedOutputToBlock
         infraSucceeded:(BOOL *)infraSucceeded
                  error:(NSError **)error
{
  NSString *outputPath = MakeTempFileWithPrefix(@"output");
  NSFileHandle *outputHandle = [NSFileHandle fileHandleForReadingAtPath:outputPath];

  LineReader *reader = [[[LineReader alloc] initWithFileHandle:outputHandle] autorelease];
  reader.didReadLineBlock = feedOutputToBlock;

  DTiPhoneSimulatorSessionConfig *sessionConfig = [self sessionConfigForRunningTestsOnSimulator:simInfo
                                                                          applicationLaunchArgs:launchArgs
                                                                   applicationLaunchEnvironment:launchEnvironment
                                                                                     outputPath:outputPath];

  SimulatorLauncher *launcher = [[[SimulatorLauncher alloc] initWithSessionConfig:sessionConfig
                                                                       deviceName:[simInfo simulatedDeviceInfoName]] autorelease];

  [reader startReading];

  BOOL simStartedSuccessfully = [launcher launchAndWaitForExit];
  if (!simStartedSuccessfully) {
    *error = launcher.launchError;
  }

  [reader stopReading];
  [reader finishReadingToEndOfFile];

  if (simStartedSuccessfully) {
    *infraSucceeded = YES;
  } else {
    *infraSucceeded = NO;
  }
}

+ (BOOL)uninstallTestHostBundleID:(NSString *)testHostBundleID
                    simulatorInfo:(SimulatorInfo *)simInfo
                        reporters:(NSArray *)reporters
                            error:(NSString **)error
{
  ReportStatusMessageBegin(reporters,
                           REPORTER_MESSAGE_INFO,
                           @"Uninstalling '%@' to get a fresh install ...",
                           testHostBundleID);
  NSError *localError = nil;
  BOOL uninstalled = [self runMobileInstallationHelperWithArguments:@[@"uninstall", testHostBundleID]
                                                      simulatorInfo:simInfo
                                                              error:&localError];
  if (uninstalled) {
    ReportStatusMessageEnd(reporters,
                           REPORTER_MESSAGE_INFO,
                           @"Uninstalled '%@' to get a fresh install.",
                           testHostBundleID);
    return YES;
  } else {
    ReportStatusMessageEnd(reporters,
                           REPORTER_MESSAGE_WARNING,
                           @"Tried to uninstall the test host app '%@' but failed.",
                           testHostBundleID);
    *error = [NSString stringWithFormat:
              @"Failed to uninstall the test host app '%@' "
              @"before running tests: %@",
              testHostBundleID, localError.localizedDescription ?: @"Failed for unknown reason."];
    return NO;
  }
}

+ (BOOL)installTestHostBundleID:(NSString *)testHostBundleID
                 fromBundlePath:(NSString *)testHostBundlePath
                  simulatorInfo:(SimulatorInfo *)simInfo
                      reporters:(NSArray *)reporters
                          error:(NSString **)error
{
  ReportStatusMessageBegin(reporters,
                           REPORTER_MESSAGE_INFO,
                           @"Installing '%@' ...",
                           testHostBundleID);
  NSError *localError = nil;
  BOOL installed = [self runMobileInstallationHelperWithArguments:@[@"install", testHostBundlePath,]
                                                    simulatorInfo:simInfo
                                                            error:&localError];
  if (installed) {
    ReportStatusMessageEnd(reporters,
                           REPORTER_MESSAGE_INFO,
                           @"Installed '%@'.",
                           testHostBundleID);
    return YES;
  } else {
    ReportStatusMessageEnd(reporters,
                           REPORTER_MESSAGE_WARNING,
                           @"Tried to install the test host app '%@' but failed.",
                           testHostBundleID);
    *error = [NSString stringWithFormat:
              @"Failed to install the test host app '%@': %@",
              testHostBundleID, localError.localizedDescription ?: @"Failed for unknown reason."];

    return NO;
  }
}

@end
