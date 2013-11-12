//
// Copyright 2013 Facebook
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

#import <launch.h>

#import "LineReader.h"
#import "ReportStatus.h"
#import "SimulatorLauncher.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"

static const NSInteger kMaxInstallOrUninstallAttempts = 3;

static void GetJobsIterator(const launch_data_t launch_data, const char *key, void *context) {
  void (^block)(const launch_data_t, const char *) = context;
  block(launch_data, key);
}

static void StopAndRemoveLaunchdJob(NSString *job)
{
  launch_data_t stopMessage = launch_data_alloc(LAUNCH_DATA_DICTIONARY);
  launch_data_dict_insert(stopMessage,
                          launch_data_new_string([job UTF8String]),
                          LAUNCH_KEY_REMOVEJOB);
  launch_data_t stopResponse = launch_msg(stopMessage);

  launch_data_free(stopMessage);
  launch_data_free(stopResponse);
}

static NSArray *GetLaunchdJobsForSimulator()
{
  launch_data_t getJobsMessage = launch_data_new_string(LAUNCH_KEY_GETJOBS);
  launch_data_t response = launch_msg(getJobsMessage);

  assert(launch_data_get_type(response) == LAUNCH_DATA_DICTIONARY);

  NSMutableArray *jobs = [NSMutableArray array];

  launch_data_dict_iterate(response,
                           GetJobsIterator,
                           ^(const launch_data_t launch_data, const char *keyCString)
  {
    NSString *key = [NSString stringWithCString:keyCString
                                       encoding:NSUTF8StringEncoding];

    NSArray *strings = @[@"com.apple.iphonesimulator",
                         @"UIKitApplication",
                         @"SimulatorBridge",
                         ];

    BOOL matches = NO;
    for (NSString *str in strings) {
      if ([key rangeOfString:str options:NSCaseInsensitiveSearch].length > 0) {
        matches = YES;
        break;
      }
    }

    if (matches) {
      [jobs addObject:key];
    }
  });

  launch_data_free(response);
  launch_data_free(getJobsMessage);

  return jobs;
}

static void KillSimulatorJobs()
{
  NSArray *jobs = GetLaunchdJobsForSimulator();

  // Tell launchd to remove each of them and trust that launchd will make sure
  // they're dead.  It'll be nice at first (sending SIGTERM) but if the process
  // doesn't die, it'll follow up with a SIGKILL.
  for (NSString *job in jobs) {
    StopAndRemoveLaunchdJob(job);
  }

  // It can take a moment for each them to die.
  while ([GetLaunchdJobsForSimulator() count] > 0) {
    [NSThread sleepForTimeInterval:0.1];
  }
}

@implementation OCUnitIOSAppTestRunner

- (NSNumber *)simulatedDeviceFamily {
  return [[_simulatorType lowercaseString] isEqualToString:@"ipad"] ? @2 : @1;
}

- (DTiPhoneSimulatorSessionConfig *)sessionConfigForRunningTestsWithEnvironment:(NSDictionary *)environment
                                                                     outputPath:(NSString *)outputPath
{
  // Sometimes the TEST_HOST will be wrapped in double quotes.
  NSString *testHostPath = [_buildSettings[@"TEST_HOST"] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
  NSString *testHostAppPath = [testHostPath stringByDeletingLastPathComponent];

  NSString *sdkVersion = [_buildSettings[@"SDK_NAME"] stringByReplacingOccurrencesOfString:@"iphonesimulator" withString:@""];
  NSString *ideBundleInjectionLibPath = @"/../../Library/PrivateFrameworks/IDEBundleInjection.framework/IDEBundleInjection";
  NSString *testBundlePath = [NSString stringWithFormat:@"%@/%@", _buildSettings[@"BUILT_PRODUCTS_DIR"], _buildSettings[@"FULL_PRODUCT_NAME"]];

  DTiPhoneSimulatorSystemRoot *systemRoot = [DTiPhoneSimulatorSystemRoot rootWithSDKVersion:sdkVersion];
  DTiPhoneSimulatorApplicationSpecifier *appSpec =
  [DTiPhoneSimulatorApplicationSpecifier specifierWithApplicationPath:testHostAppPath];

  DTiPhoneSimulatorSessionConfig *sessionConfig = [[[DTiPhoneSimulatorSessionConfig alloc] init] autorelease];
  [sessionConfig setApplicationToSimulateOnStart:appSpec];
  [sessionConfig setSimulatedSystemRoot:systemRoot];
  [sessionConfig setSimulatedDeviceFamily:[self simulatedDeviceFamily]];
  [sessionConfig setSimulatedApplicationShouldWaitForDebugger:NO];
  
  [sessionConfig setSimulatedApplicationLaunchArgs:[self testArguments]];

  NSMutableDictionary *launchEnvironment = [NSMutableDictionary dictionary];
  [launchEnvironment addEntriesFromDictionary:environment];
  [launchEnvironment addEntriesFromDictionary:@{
   @"DYLD_FRAMEWORK_PATH" : _buildSettings[@"TARGET_BUILD_DIR"],
   @"DYLD_LIBRARY_PATH" : _buildSettings[@"TARGET_BUILD_DIR"],
   @"DYLD_INSERT_LIBRARIES" : [@[
                                 [XCToolLibPath() stringByAppendingPathComponent:@"otest-shim-ios.dylib"],
                               ideBundleInjectionLibPath,
                               ] componentsJoinedByString:@":"],
   @"NSUnbufferedIO" : @"YES",
   @"XCInjectBundle" : testBundlePath,
   @"XCInjectBundleInto" : testHostPath,
   }];
  [sessionConfig setSimulatedApplicationLaunchEnvironment:
   [self otestEnvironmentWithOverrides:launchEnvironment]];

  [sessionConfig setSimulatedApplicationStdOutPath:outputPath];
  [sessionConfig setSimulatedApplicationStdErrPath:outputPath];

  [sessionConfig setLocalizedClientName:@"xctool"];

  return sessionConfig;
}

- (BOOL)runMobileInstallationHelperWithArguments:(NSArray *)arguments
{
  NSString *sdkVersion = [_buildSettings[@"SDK_NAME"] stringByReplacingOccurrencesOfString:@"iphonesimulator"
                                                                                withString:@""];
  DTiPhoneSimulatorSystemRoot *systemRoot = [DTiPhoneSimulatorSystemRoot rootWithSDKVersion:sdkVersion];
  DTiPhoneSimulatorApplicationSpecifier *appSpec = [DTiPhoneSimulatorApplicationSpecifier specifierWithApplicationPath:
                                                    [XCToolLibExecPath() stringByAppendingPathComponent:@"mobile-installation-helper.app"]];
  DTiPhoneSimulatorSessionConfig *sessionConfig = [[[DTiPhoneSimulatorSessionConfig alloc] init] autorelease];
  [sessionConfig setApplicationToSimulateOnStart:appSpec];
  [sessionConfig setSimulatedSystemRoot:systemRoot];
  [sessionConfig setSimulatedDeviceFamily:[self simulatedDeviceFamily]];
  [sessionConfig setSimulatedApplicationShouldWaitForDebugger:NO];
  [sessionConfig setLocalizedClientName:@"xctool"];
  [sessionConfig setSimulatedApplicationLaunchArgs:arguments];
  [sessionConfig setSimulatedApplicationLaunchEnvironment:@{}];

  SimulatorLauncher *launcher = [[[SimulatorLauncher alloc] initWithSessionConfig:sessionConfig
                                                                       deviceName:_deviceName] autorelease];

  return [launcher launchAndWaitForExit];
}

/**
 * Use the iPhoneSimulatorRemoteClient framework to start the app in the sim,
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
- (void)runTestsInSimulator:(NSString *)testHostAppPath
          feedOutputToBlock:(void (^)(NSString *))feedOutputToBlock
             testsSucceeded:(BOOL *)testsSucceeded
             infraSucceeded:(BOOL *)infraSucceeded
{
  NSString *exitModePath = MakeTempFileWithPrefix(@"exit-mode");
  NSString *outputPath = MakeTempFileWithPrefix(@"output");
  NSFileHandle *outputHandle = [NSFileHandle fileHandleForReadingAtPath:outputPath];

  LineReader *reader = [[[LineReader alloc] initWithFileHandle:outputHandle] autorelease];
  reader.didReadLineBlock = feedOutputToBlock;

  // otest-shim will be inserted into the process and will interpose the exit()
  // and abort() functions, and write the exit status of the app to whatever
  // is specified in SAVE_EXIT_MODE_TO.
  //
  // We only do this because the simulator API gives us no easy way to get the
  // exit status of the app we launch, and we use the exit status to tell if
  // all tests in a given test bundle ran successfully.
  DTiPhoneSimulatorSessionConfig *sessionConfig =
    [self sessionConfigForRunningTestsWithEnvironment:@{
     @"SAVE_EXIT_MODE_TO" : exitModePath,
     }
                                           outputPath:outputPath];

  [sessionConfig setSimulatedApplicationStdOutPath:outputPath];
  [sessionConfig setSimulatedApplicationStdErrPath:outputPath];

  SimulatorLauncher *launcher = [[[SimulatorLauncher alloc] initWithSessionConfig:sessionConfig
                                                                       deviceName:_deviceName] autorelease];

  [reader startReading];

  BOOL simStartedSuccessfully = [launcher launchAndWaitForExit];

  [reader stopReading];
  [reader finishReadingToEndOfFile];

  BOOL exitStatusWasWritten = [[NSFileManager defaultManager] fileExistsAtPath:exitModePath
                                                                   isDirectory:NULL];

  if (simStartedSuccessfully && exitStatusWasWritten) {
    NSDictionary *exitMode = [NSDictionary dictionaryWithContentsOfFile:exitModePath];

    [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:exitModePath error:nil];

    *testsSucceeded = [exitMode[@"via"] isEqualToString:@"exit"] && ([exitMode[@"status"] intValue] == 0);
    *infraSucceeded = YES;
  } else {
    *testsSucceeded = NO;
    *infraSucceeded = NO;
  }
}

- (BOOL)uninstallTestHostBundleID:(NSString *)testHostBundleID withError:(NSString **)error
{
  ReportStatusMessageBegin(_reporters,
                           REPORTER_MESSAGE_INFO,
                           @"Uninstalling '%@' to get a fresh install ...",
                           testHostBundleID);
  BOOL uninstalled = [self runMobileInstallationHelperWithArguments:@[
                      @"uninstall",
                      testHostBundleID,
                      ]];
  if (uninstalled) {
    ReportStatusMessageEnd(_reporters,
                           REPORTER_MESSAGE_INFO,
                           @"Uninstalled '%@' to get a fresh install.",
                           testHostBundleID);
    return YES;
  } else {
    ReportStatusMessageEnd(_reporters,
                           REPORTER_MESSAGE_WARNING,
                           @"Tried to uninstall the test host app '%@' but failed.",
                           testHostBundleID);
    *error = [NSString stringWithFormat:
              @"Failed to uninstall the test host app '%@' "
              @"before running tests.",
              testHostBundleID];
    return NO;
  }
}

- (BOOL)installTestHostBundleID:(NSString *)testHostBundleID
                 fromBundlePath:(NSString *)testHostBundlePath
                          error:(NSString **)error
{
  ReportStatusMessageBegin(_reporters,
                           REPORTER_MESSAGE_INFO,
                           @"Installing '%@' ...",
                           testHostBundleID);
  BOOL installed = [self runMobileInstallationHelperWithArguments:@[
                    @"install",
                    testHostBundlePath,
                    ]];
  if (installed) {
    ReportStatusMessageEnd(_reporters,
                           REPORTER_MESSAGE_INFO,
                           @"Installed '%@'.",
                           testHostBundleID);
    return YES;
  } else {
    ReportStatusMessageEnd(_reporters,
                           REPORTER_MESSAGE_WARNING,
                           @"Tried to install the test host app '%@' but failed.",
                           testHostBundleID);
    *error = [NSString stringWithFormat:
              @"Failed to install the test host app '%@'.",
              testHostBundleID];

    return NO;
  }
}

- (BOOL)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock
       testsNotStartedOrErrored:(BOOL *)testsNotStartedOrErrored
                          error:(NSString **)error
{
  NSString *sdkName = _buildSettings[@"SDK_NAME"];
  NSAssert([sdkName hasPrefix:@"iphonesimulator"], @"Unexpected SDK: %@", sdkName);

  // Sometimes the TEST_HOST will be wrapped in double quotes.
  NSString *testHostPath = [_buildSettings[@"TEST_HOST"] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
  NSString *testHostAppPath = [testHostPath stringByDeletingLastPathComponent];
  NSString *testHostPlistPath = [[testHostPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Info.plist"];

  if (![[NSFileManager defaultManager] isExecutableFileAtPath:testHostPath]) {
    ReportStatusMessage(_reporters, REPORTER_MESSAGE_ERROR,
                        @"Your TEST_HOST '%@' does not appear to be an executable.", testHostPath);
    *testsNotStartedOrErrored = YES;
    *error = @"TEST_HOST not executable.";
    return NO;
  }

  NSDictionary *testHostInfoPlist = [NSDictionary dictionaryWithContentsOfFile:testHostPlistPath];
  if (!testHostInfoPlist) {
    ReportStatusMessage(_reporters, REPORTER_MESSAGE_ERROR,
                        @"Info.plist for TEST_HOST missing or malformatted.");
    *testsNotStartedOrErrored = YES;
    *error = @"Bad Info.plist for TEST_HOST";
    return NO;
  }

  NSString *testHostBundleID = testHostInfoPlist[@"CFBundleIdentifier"];
  NSAssert(testHostBundleID != nil, @"Missing 'CFBundleIdentifier' in Info.plist");

  BOOL (^prepTestEnv)() = ^BOOL() {
    if (_freshSimulator) {
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

    if (_freshInstall) {
      if (![self uninstallTestHostBundleID:testHostBundleID withError:error]) {
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
    if (![self installTestHostBundleID:testHostBundleID
                        fromBundlePath:testHostAppPath
                                 error:error]) {
      return NO;
    }
    return YES;
  };

  // Sometimes test host app installation fails, and all subsequent installation attempts fail as well.
  // Instead of retrying the installation after failure, we'll kill and relaunch the simulator before
  // the install, and also wait a short amount of time before each attempt.
  for (NSInteger remainingAttempts = kMaxInstallOrUninstallAttempts - 1; remainingAttempts >= 0; --remainingAttempts) {
    if (prepTestEnv(error)) {
      break;
    } else {
      NSCAssert(error, @"If preparing the test env failed, there should be a description of what failed.");
      if (remainingAttempts > 0) {
        ReportStatusMessage(_reporters,
                            REPORTER_MESSAGE_INFO,
                            @"Preparing test environment failed; "
                            @"will retry %ld more time%@",
                            (long)remainingAttempts,
                            remainingAttempts == 1 ? @"" : @"s");
        // Sometimes, the test host app installation retries are starting and
        // finishing in < 10 ms. That's way too fast for anything real to be
        // happening. To remedy this, we pause for a second between retries.
        [NSThread sleepForTimeInterval:1];
      }
      else {
        ReportStatusMessage(_reporters,
                            REPORTER_MESSAGE_INFO,
                            @"Preparing test environment failed.");
        *testsNotStartedOrErrored = YES;
        return NO;
      }
    }
  }

  ReportStatusMessage(_reporters,
                      REPORTER_MESSAGE_INFO,
                      @"Launching test host and running tests ...");

  BOOL testsSucceeded = NO;
  BOOL infraSucceeded = NO;
  [self runTestsInSimulator:testHostAppPath
          feedOutputToBlock:outputLineBlock
             testsSucceeded:&testsSucceeded
             infraSucceeded:&infraSucceeded];

  *testsNotStartedOrErrored = !infraSucceeded;
  
  if (!infraSucceeded) {
    *error = @"The simulator failed to start, or the TEST_HOST application failed to run.";
    return NO;
  } else {
    return testsSucceeded;
  }
}

@end
