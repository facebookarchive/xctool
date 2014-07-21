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
#import "SimulatorWrapperInternal.h"
#import "SimulatorWrapperXcode5.h"
#import "SimulatorWrapperXcode6.h"

#import "DTiPhoneSimulatorRemoteClient.h"
#import "LineReader.h"
#import "ReportStatus.h"
#import "SimulatorInfo.h"
#import "SimulatorLauncher.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

static const NSString * kOtestShimStdoutFilePath = @"OTEST_SHIM_STDOUT_FILE";
static const NSString * kOtestShimStderrFilePath __unused = @"OTEST_SHIM_STDERR_FILE";

@implementation SimulatorWrapper

#pragma mark -
#pragma mark Internal

+ (DTiPhoneSimulatorSessionConfig *)sessionConfigForRunningTestsOnSimulator:(SimulatorInfo *)simInfo
                                                      applicationLaunchArgs:(NSArray *)launchArgs
                                               applicationLaunchEnvironment:(NSDictionary *)launchEnvironment
                                                                 outputPath:(NSString *)outputPath
{
  // Sometimes the TEST_HOST will be wrapped in double quotes.
  NSString *testHostPath = [simInfo.buildSettings[Xcode_TEST_HOST] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
  NSString *testHostAppPath = [testHostPath stringByDeletingLastPathComponent];

  DTiPhoneSimulatorSystemRoot *systemRoot = [simInfo systemRootForSimulatedSdk];

  DTiPhoneSimulatorApplicationSpecifier *appSpec =
  [DTiPhoneSimulatorApplicationSpecifier specifierWithApplicationPath:testHostAppPath];

  NSMutableDictionary *launchEnvironmentEdited = [launchEnvironment mutableCopy];
  launchEnvironmentEdited[kOtestShimStdoutFilePath] = outputPath;

  DTiPhoneSimulatorSessionConfig *sessionConfig = [[DTiPhoneSimulatorSessionConfig alloc] init];
  [sessionConfig setApplicationToSimulateOnStart:appSpec];
  [sessionConfig setSimulatedApplicationLaunchArgs:launchArgs];
  [sessionConfig setSimulatedApplicationLaunchEnvironment:launchEnvironmentEdited];
  [sessionConfig setSimulatedApplicationShouldWaitForDebugger:NO];
  [sessionConfig setSimulatedArchitecture:[simInfo simulatedArchitecture]];
  [sessionConfig setSimulatedDeviceFamily:[simInfo simulatedDeviceFamily]];
  [sessionConfig setSimulatedDeviceInfoName:[simInfo simulatedDeviceInfoName]];
  [sessionConfig setSimulatedSystemRoot:systemRoot];
  [sessionConfig setLocalizedClientName:@"xctool"];

  // Don't let anything from STDERR get in our stream.  Normally, once
  // otest-shim gets loaded, we don't have to worry about whatever is coming
  // over STDERR since the shim will redirect all output (including STDERR) into
  // JSON outout on STDOUT.
  //
  // But, even before otest-shim loads, there's a chance something else may spew
  // into STDERR.  This happened in --
  // https://github.com/facebook/xctool/issues/224#issuecomment-29288004
  [sessionConfig setSimulatedApplicationStdErrPath:@"/dev/null"];

  return sessionConfig;
}

#pragma mark -
#pragma mark Helpers

+ (Class)classBasedOnCurrentVersionOfXcode
{
  if (ToolchainIsXcode6OrBetter()) {
    return [SimulatorWrapperXcode6 class];
  } else {
    return [SimulatorWrapperXcode5 class];
  }
}

#pragma mark -
#pragma mark Main Methods

+ (BOOL)runHostAppTests:(NSString *)testHostAppPath
          simulatorInfo:(SimulatorInfo *)simInfo
          appLaunchArgs:(NSArray *)launchArgs
   appLaunchEnvironment:(NSDictionary *)launchEnvironment
      feedOutputToBlock:(void (^)(NSString *))feedOutputToBlock
                  error:(NSError **)error
{
  NSString *outputPath = MakeTempFileWithPrefix(@"output");
  NSFileHandle *outputHandle = [NSFileHandle fileHandleForReadingAtPath:outputPath];

  LineReader *reader = [[LineReader alloc] initWithFileHandle:outputHandle];
  reader.didReadLineBlock = feedOutputToBlock;

  DTiPhoneSimulatorSessionConfig *sessionConfig =
    [[self classBasedOnCurrentVersionOfXcode] sessionConfigForRunningTestsOnSimulator:simInfo
                                                                applicationLaunchArgs:launchArgs
                                                         applicationLaunchEnvironment:launchEnvironment
                                                                           outputPath:outputPath];

  SimulatorLauncher *launcher = [[SimulatorLauncher alloc] initWithSessionConfig:sessionConfig
                                                                      deviceName:[simInfo simulatedDeviceInfoName]];
  launcher.launchTimeout = [simInfo launchTimeout];

  [reader startReading];

  BOOL simStartedSuccessfully = [launcher launchAndWaitForExit];
  if (!simStartedSuccessfully && error) {
    *error = launcher.launchError;
  }

  [reader stopReading];
  [reader finishReadingToEndOfFile];
  return  simStartedSuccessfully;
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

  BOOL uninstalled = [[self classBasedOnCurrentVersionOfXcode] uninstallTestHostBundleID:testHostBundleID
                                                                           simulatorInfo:simInfo
                                                                               reporters:reporters
                                                                                   error:error];
  if (uninstalled) {
    ReportStatusMessageEnd(reporters,
                           REPORTER_MESSAGE_INFO,
                           @"Uninstalled '%@' to get a fresh install.",
                           testHostBundleID);
  } else {
    ReportStatusMessageEnd(reporters,
                           REPORTER_MESSAGE_WARNING,
                           @"Tried to uninstall the test host app '%@' but failed.",
                           testHostBundleID);
  }
  return uninstalled;
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

  BOOL installed = [[self classBasedOnCurrentVersionOfXcode] installTestHostBundleID:testHostBundleID
                                                                      fromBundlePath:testHostBundlePath
                                                                       simulatorInfo:simInfo
                                                                           reporters:reporters
                                                                               error:error];
  if (installed) {
    ReportStatusMessageEnd(reporters,
                           REPORTER_MESSAGE_INFO,
                           @"Installed '%@'.",
                           testHostBundleID);
  } else {
    ReportStatusMessageEnd(reporters,
                           REPORTER_MESSAGE_WARNING,
                           @"Tried to install the test host app '%@' but failed.",
                           testHostBundleID);
  }
  return installed;
}

@end
