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

#import "OCUnitIOSAppTestRunner.h"

#import "ReportStatus.h"
#import "SimulatorInfo.h"
#import "SimulatorUtils.h"
#import "SimulatorWrapper.h"
#import "XcodeBuildSettings.h"
#import "XCToolUtil.h"

static const NSInteger kMaxInstallOrUninstallAttempts = 3;
static const NSInteger kMaxRunTestsAttempts = 3;

@implementation OCUnitIOSAppTestRunner

- (void)runTestsAndFeedOutputTo:(FdOutputLineFeedBlock)outputLineBlock
                   startupError:(NSString **)startupError
                    otherErrors:(NSString **)otherErrors
{
  NSString *sdkName = _buildSettings[Xcode_SDK_NAME];
  NSAssert([sdkName hasPrefix:@"iphonesimulator"] || [sdkName hasPrefix:@"appletvsimulator"], @"Unexpected SDK: %@", sdkName);

  // Sometimes the TEST_HOST will be wrapped in double quotes.
  NSString *testHostPath = [_buildSettings[Xcode_TEST_HOST] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
  NSString *testHostAppPath = [testHostPath stringByDeletingLastPathComponent];
  NSString *testHostPlistPath = [[testHostPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Info.plist"];

  if (![[NSFileManager defaultManager] isExecutableFileAtPath:testHostPath]) {
    ReportStatusMessage(_reporters, REPORTER_MESSAGE_ERROR,
                        @"Your TEST_HOST '%@' does not appear to be an executable.", testHostPath);
    *startupError = @"TEST_HOST not executable.";
    return;
  }

  NSDictionary *testHostInfoPlist = [NSDictionary dictionaryWithContentsOfFile:testHostPlistPath];
  if (!testHostInfoPlist) {
    ReportStatusMessage(_reporters, REPORTER_MESSAGE_ERROR,
                        @"Info.plist for TEST_HOST missing or malformatted.");
    *startupError = @"Bad Info.plist for TEST_HOST";
    return;
  }

  NSString *testHostBundleID = testHostInfoPlist[@"CFBundleIdentifier"];
  NSAssert(testHostBundleID != nil, @"Missing 'CFBundleIdentifier' in Info.plist");

  BOOL (^prepareSimulator)(BOOL freshSimulator, BOOL resetSimulator) = ^(BOOL freshSimulator, BOOL resetSimulator) {
    if (freshSimulator || resetSimulator) {
      ReportStatusMessageBegin(_reporters,
                               REPORTER_MESSAGE_INFO,
                               @"Verifying iOS Simulators...");
      NSString *verifyError = nil;
      if (VerifySimulators(&verifyError)) {
        ReportStatusMessageEnd(_reporters,
                               REPORTER_MESSAGE_INFO,
                               @"Verified iOS Simulators...");
      } else {
        ReportStatusMessageEnd(_reporters,
                               REPORTER_MESSAGE_ERROR,
                               @"Failed to verify iOS Simulators with error: %@", verifyError);
      }

      ReportStatusMessageBegin(_reporters,
                               REPORTER_MESSAGE_INFO,
                               @"Shutting down iOS Simulator...");
      NSString *shutdownError = nil;
      if (ShutdownSimulator(_simulatorInfo, &shutdownError)) {
        ReportStatusMessageEnd(_reporters,
                               REPORTER_MESSAGE_INFO,
                               @"Shut down iOS Simulator...");
      } else {
        ReportStatusMessageEnd(_reporters,
                               REPORTER_MESSAGE_WARNING,
                               @"Failed to shut down iOS Simulator with error: %@", shutdownError);
      }

      ReportStatusMessageBegin(_reporters,
                               REPORTER_MESSAGE_INFO,
                               @"Stopping any existing iOS simulator jobs to get a "
                               @"fresh simulator ...");
      KillSimulatorJobs();
      ReportStatusMessageEnd(_reporters,
                             REPORTER_MESSAGE_INFO,
                             @"Stopped any existing iOS simulator jobs to get a "
                             @"fresh simulator.");
    }

    if (resetSimulator) {
      ReportStatusMessageBegin(_reporters,
                               REPORTER_MESSAGE_INFO,
                               @"Resetting iOS simulator content and settings...");
      NSString *removedPath = nil;
      NSString *removeError = nil;
      if (RemoveSimulatorContentAndSettings(_simulatorInfo, &removedPath, &removeError)) {
        if (removedPath) {
          ReportStatusMessageEnd(_reporters,
                                 REPORTER_MESSAGE_INFO,
                                 @"Reset iOS simulator content and settings at path \"%@\"",
                                 removedPath);
        } else {
          ReportStatusMessageEnd(_reporters,
                                 REPORTER_MESSAGE_INFO,
                                 @"Reset iOS simulator content and settings.");
        }
      } else {
        ReportStatusMessageEnd(_reporters,
                               REPORTER_MESSAGE_WARNING,
                               @"Failed to reset iOS simulator content and settings at path \"%@\" with error: %@",
                               removedPath, removeError);

      }
    }

   if (![SimulatorWrapper prepareSimulator:[_simulatorInfo simulatedDevice]
                      newSimulatorInstance:_newSimulatorInstance
                                 reporters:_reporters
                                     error:startupError]) {
      return NO;
    }

    return YES;
  };

  BOOL (^prepTestEnv)() = ^BOOL() {
    if (!prepareSimulator(_freshSimulator, _resetSimulator)) {
      return NO;
    }

    if (_freshInstall) {
      if (![SimulatorWrapper uninstallTestHostBundleID:testHostBundleID
                                                device:[_simulatorInfo simulatedDevice]
                                             reporters:_reporters
                                                 error:startupError]) {
        return NO;
      }
    }

    // Always install the app before running it.  We've observed that
    // DTiPhoneSimulatorSession does not reliably set the application launch
    // environment.  If the app is not already installed on the simulator and you
    // set the launch environment via (setSimulatedApplicationLaunchEnvironment:),
    // then _sometimes_ the environment gets set right and sometimes not.  This
    // would make test sometimes not run, since the test runner depends on
    // DYLD_INSERT_LIBARIES getting passed to the test host app.
    //
    // By making sure the app is already installed, we guarantee the environment
    // is always set correctly.
    if (![SimulatorWrapper installTestHostBundleID:testHostBundleID
                                    fromBundlePath:testHostAppPath
                                            device:[_simulatorInfo simulatedDevice]
                                         reporters:_reporters
                                             error:startupError]) {
      return NO;
    }
    return YES;
  };

  // Sometimes test host app installation fails, and all subsequent installation attempts fail as well.
  // Instead of retrying the installation after failure, we'll kill and relaunch the simulator before
  // the install, and also wait a short amount of time before each attempt.
  for (NSInteger remainingAttempts = kMaxInstallOrUninstallAttempts - 1; remainingAttempts >= 0; --remainingAttempts) {
    if (prepTestEnv(startupError)) {
      break;
    }

    NSCAssert(startupError, @"If preparing the test env failed, there should be a description of what failed.");
    if (!remainingAttempts) {
      ReportStatusMessage(_reporters,
                          REPORTER_MESSAGE_WARNING,
                          @"Preparing test environment failed.");
      return;
    }

    ReportStatusMessage(_reporters,
                        REPORTER_MESSAGE_INFO,
                        @"Preparing test environment failed; "
                        @"will retry %ld more time%@",
                        (long)remainingAttempts,
                        remainingAttempts == 1 ? @"" : @"s");

    // we will reset iOS simulator contents and settings now if it is not done in `prepTestEnv`
    if (!_resetSimulator) {
      prepareSimulator(YES, !_noResetSimulatorOnFailure);
    }

    // Sometimes, the test host app installation retries are starting and
    // finishing in < 10 ms. That's way too fast for anything real to be
    // happening. To remedy this, we pause for a second between retries.
    [NSThread sleepForTimeInterval:1];
  }

  NSArray *appLaunchArgs = nil;
  NSMutableDictionary *appLaunchEnvironment = [_simulatorInfo simulatorLaunchEnvironment];
  if (ToolchainIsXcode7OrBetter()) {
    appLaunchArgs = [self commonTestArguments];

    [appLaunchEnvironment addEntriesFromDictionary:[self testEnvironmentWithSpecifiedTestConfiguration]];
  } else {
    appLaunchArgs = [self testArgumentsWithSpecifiedTestsToRun];
  }
  appLaunchEnvironment = [self otestEnvironmentWithOverrides:appLaunchEnvironment];

  // Sometimes simulator or test host app fails to run.
  // Let's try several times to run before reporting about failure to callers.
  for (NSInteger remainingAttempts = kMaxRunTestsAttempts - 1; remainingAttempts >= 0; --remainingAttempts) {
    NSError *error = nil;
    BOOL infraSucceeded = [SimulatorWrapper runHostAppTests:testHostBundleID
                                                     device:[_simulatorInfo simulatedDevice]
                                                  arguments:appLaunchArgs
                                                environment:appLaunchEnvironment
                                          feedOutputToBlock:outputLineBlock
                                                  reporters:_reporters
                                                      error:&error];

    if (infraSucceeded) {
      break;
    }

    *startupError = @"The simulator failed to start, or the TEST_HOST application failed to run.";
    if (error.localizedDescription) {
      *startupError = [*startupError stringByAppendingFormat:@" Simulator error: %@", error.localizedDescription];
    }

    if (!remainingAttempts) {
      ReportStatusMessage(_reporters,
                          REPORTER_MESSAGE_ERROR,
                          @"%@.",
                          *startupError);
      return;
    }

    ReportStatusMessage(_reporters,
                        REPORTER_MESSAGE_INFO,
                        @"%@; "
                        @"will retry %ld more time%@.",
                        *startupError,
                        (long)remainingAttempts,
                        remainingAttempts == 1 ? @"" : @"s");
    // We pause for a second between retries.
    [NSThread sleepForTimeInterval:1];

    // Restarting simulator
    prepareSimulator(YES, NO);
  }
}

@end
