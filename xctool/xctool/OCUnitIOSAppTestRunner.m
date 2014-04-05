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

#import "ISHDeviceInfo.h"
#import "ISHDeviceVersions.h"
#import "ISHSDKInfo.h"
#import "LineReader.h"
#import "ReportStatus.h"
#import "SimulatorLauncher.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

static const NSInteger KProductTypeIphone = 1;
static const NSInteger KProductTypeIpad = 2;

static const NSInteger kMaxInstallOrUninstallAttempts = 3;
static const NSInteger kMaxRunTestsAttempts = 3;

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

static BOOL RemoveSimulatorContentAndSettings(NSString *simulatorVersion, cpu_type_t cpuType, NSString **removedPath, NSString **errorMessage)
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *simulatorDirectory = [@"~/Library/Application Support/iPhone Simulator" stringByExpandingTildeInPath];
  NSError *error;

  [fileManager removeItemAtPath:[simulatorDirectory stringByAppendingPathComponent:@"Library"] error:nil];

  NSString *sdkDirectory = [simulatorVersion stringByAppendingString:cpuType == CPU_TYPE_X86_64 ? @"-64" : @""];
  NSString *simulatorContentsDirectory = [simulatorDirectory stringByAppendingPathComponent:sdkDirectory];

  if ([fileManager fileExistsAtPath:simulatorContentsDirectory]) {
    *removedPath = simulatorContentsDirectory;

    if (![fileManager removeItemAtPath:simulatorContentsDirectory error:&error]) {
      *errorMessage = [NSString stringWithFormat:@"%@; %@.",
                       error.localizedDescription ?: @"Unknown error.",
                       [error.userInfo[NSUnderlyingErrorKey] localizedDescription] ?: @""];
      return NO;
    }
  }

  return YES;
}

@implementation OCUnitIOSAppTestRunner

- (NSNumber *)simulatedDeviceFamily
{
  if (_simulatorType) {
    return [[_simulatorType lowercaseString] isEqualToString:@"ipad"] ? @(KProductTypeIpad) : @(KProductTypeIphone);
  } else {
    return @([_buildSettings[Xcode_TARGETED_DEVICE_FAMILY] integerValue]);
  }
}

- (NSString *)simulatedDeviceInfoName
{
  if (_deviceName) {
    return _deviceName;
  }

  NSString *probableDeviceName;
  switch ([[self simulatedDeviceFamily] integerValue]) {
    case KProductTypeIphone:
      probableDeviceName = @"iPhone";
      break;

    case KProductTypeIpad:
      probableDeviceName = @"iPad";
      break;
  }

  DTiPhoneSimulatorSystemRoot *systemRoot = [DTiPhoneSimulatorSystemRoot rootWithSDKVersion:[self sdkVersion]];
  if (!systemRoot) {
    return probableDeviceName;
  }

  ISHDeviceVersions *versions = [ISHDeviceVersions sharedInstance];
  ISHSDKInfo *latestSDKInfo = [versions sdkFromSDKRoot:[systemRoot sdkRootPath]];
  ISHDeviceInfo *deviceInfo = [versions deviceInfoNamed:probableDeviceName];
  while (deviceInfo && ![deviceInfo supportsSDK:latestSDKInfo]) {
    deviceInfo = [deviceInfo newerEquivalent];
    probableDeviceName = [deviceInfo displayName];
  }

  return probableDeviceName;
}

- (NSString *)simulatedArchitecture
{
  switch (self.cpuType) {
    case CPU_TYPE_I386:
      return @"i386";

    case CPU_TYPE_X86_64:
      return @"x86_64";
  }
  return @"i386";
}

- (NSString *)sdkVersion
{
  NSString *sdkVersion = [_buildSettings[Xcode_IPHONEOS_DEPLOYMENT_TARGET] stringByReplacingOccurrencesOfString:@"iphonesimulator" withString:@""];
  if (self.OSVersion) {
    if ([self.OSVersion isEqualTo:@"latest"]) {
      sdkVersion = [[[ISHDeviceVersions sharedInstance] sdkFromSDKRoot:[[ISHDeviceVersions sharedInstance] latestSDKRoot]] shortVersionString];
    } else {
      sdkVersion = self.OSVersion;
    }
  }
  return sdkVersion;
}

- (NSString *)maxSdkVersionForSimulatedDevice
{
  ISHDeviceVersions *versions = [ISHDeviceVersions sharedInstance];
  ISHDeviceInfo *deviceInfo = [versions deviceInfoNamed:[self simulatedDeviceInfoName]];
  ISHSDKInfo *maxSdk = nil;
  for (ISHSDKInfo *sdkInfo in [versions allSDKs]) {
    if (![deviceInfo supportsSDK:sdkInfo]) {
      continue;
    }
    if ([sdkInfo version] > [maxSdk version]) {
      maxSdk = sdkInfo;
    }
  }
  return [maxSdk shortVersionString];
}

- (NSString *)simulatedSdkVersion
{
  if (self.OSVersion) {
    return [self sdkVersion];
  } else {
    return [self maxSdkVersionForSimulatedDevice];
  }
}

- (DTiPhoneSimulatorSystemRoot *)systemRootForSimulatedSdk
{
  NSString *sdkVersion = [self simulatedSdkVersion];
  DTiPhoneSimulatorSystemRoot *systemRoot = [DTiPhoneSimulatorSystemRoot rootWithSDKVersion:sdkVersion];
  if (systemRoot) {
    return systemRoot;
  }

  ISHDeviceVersions *versions = [ISHDeviceVersions sharedInstance];
  NSMutableArray *availableSdks = [NSMutableArray array];
  for (ISHSDKInfo *sdkInfo in [versions allSDKs]) {
    [availableSdks addObject:[sdkInfo fullVersionString]];
    if ([[sdkInfo shortVersionString] isEqualToString:sdkVersion]) {
      systemRoot = [DTiPhoneSimulatorSystemRoot rootWithSDKPath:[sdkInfo root]];
    }
  }
  NSAssert(systemRoot != nil, @"Unable to instantiate DTiPhoneSimulatorSystemRoot for sdk version: %@. Available sdks: %@", sdkVersion, availableSdks);
  return systemRoot;
}

- (DTiPhoneSimulatorSessionConfig *)sessionConfigForRunningTestsWithEnvironment:(NSDictionary *)environment
                                                                     outputPath:(NSString *)outputPath
{
  // Sometimes the TEST_HOST will be wrapped in double quotes.
  NSString *testHostPath = [_buildSettings[Xcode_TEST_HOST] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
  NSString *testHostAppPath = [testHostPath stringByDeletingLastPathComponent];

  NSString *ideBundleInjectionLibPath = @"/../../Library/PrivateFrameworks/IDEBundleInjection.framework/IDEBundleInjection";
  NSString *testBundlePath = [NSString stringWithFormat:@"%@/%@",
                              _buildSettings[Xcode_BUILT_PRODUCTS_DIR],
                              _buildSettings[Xcode_FULL_PRODUCT_NAME]];

  DTiPhoneSimulatorSystemRoot *systemRoot = [self systemRootForSimulatedSdk];

  DTiPhoneSimulatorApplicationSpecifier *appSpec =
  [DTiPhoneSimulatorApplicationSpecifier specifierWithApplicationPath:testHostAppPath];

  DTiPhoneSimulatorSessionConfig *sessionConfig = [[[DTiPhoneSimulatorSessionConfig alloc] init] autorelease];
  [sessionConfig setApplicationToSimulateOnStart:appSpec];
  [sessionConfig setSimulatedSystemRoot:systemRoot];
  [sessionConfig setSimulatedDeviceFamily:[self simulatedDeviceFamily]];
  [sessionConfig setSimulatedApplicationShouldWaitForDebugger:NO];
  [sessionConfig setSimulatedApplicationLaunchArgs:[self testArguments]];
  [sessionConfig setSimulatedDeviceInfoName:[self simulatedDeviceInfoName]];
  [sessionConfig setSimulatedArchitecture:[self simulatedArchitecture]];

  NSMutableDictionary *launchEnvironment = [NSMutableDictionary dictionary];
  [launchEnvironment addEntriesFromDictionary:environment];
  [launchEnvironment addEntriesFromDictionary:@{
   @"DYLD_FALLBACK_FRAMEWORK_PATH" : [systemRoot.sdkRootPath stringByAppendingPathComponent:@"/Developer/Library/Frameworks"],
   @"DYLD_FRAMEWORK_PATH" : _buildSettings[Xcode_TARGET_BUILD_DIR],
   @"DYLD_LIBRARY_PATH" : _buildSettings[Xcode_TARGET_BUILD_DIR],
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

- (BOOL)runMobileInstallationHelperWithArguments:(NSArray *)arguments error:(NSError **)error
{
  DTiPhoneSimulatorSystemRoot *systemRoot = [self systemRootForSimulatedSdk];

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
  [sessionConfig setSimulatedDeviceInfoName:[self simulatedDeviceInfoName]];

  SimulatorLauncher *launcher = [[[SimulatorLauncher alloc] initWithSessionConfig:sessionConfig
                                                                       deviceName:[self simulatedDeviceInfoName]] autorelease];

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
- (void)runTestsInSimulator:(NSString *)testHostAppPath
          feedOutputToBlock:(void (^)(NSString *))feedOutputToBlock
             infraSucceeded:(BOOL *)infraSucceeded
                      error:(NSError **)error
{
  NSString *outputPath = MakeTempFileWithPrefix(@"output");
  NSFileHandle *outputHandle = [NSFileHandle fileHandleForReadingAtPath:outputPath];

  LineReader *reader = [[[LineReader alloc] initWithFileHandle:outputHandle] autorelease];
  reader.didReadLineBlock = feedOutputToBlock;

  DTiPhoneSimulatorSessionConfig *sessionConfig =
    [self sessionConfigForRunningTestsWithEnvironment:@{}
                                           outputPath:outputPath];

  SimulatorLauncher *launcher = [[[SimulatorLauncher alloc] initWithSessionConfig:sessionConfig
                                                                       deviceName:[self simulatedDeviceInfoName]] autorelease];

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

- (BOOL)uninstallTestHostBundleID:(NSString *)testHostBundleID withError:(NSString **)error
{
  ReportStatusMessageBegin(_reporters,
                           REPORTER_MESSAGE_INFO,
                           @"Uninstalling '%@' to get a fresh install ...",
                           testHostBundleID);
  NSError *localError = nil;
  BOOL uninstalled = [self runMobileInstallationHelperWithArguments:@[@"uninstall", testHostBundleID]
                                                              error:&localError];
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
              @"before running tests: %@",
              testHostBundleID, localError.localizedDescription ?: @"Failed for unknown reason."];
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
  NSError *localError = nil;
  BOOL installed = [self runMobileInstallationHelperWithArguments:@[@"install", testHostBundlePath,]
                                                            error:&localError];
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
              @"Failed to install the test host app '%@': %@",
              testHostBundleID, localError.localizedDescription ?: @"Failed for unknown reason."];

    return NO;
  }
}

- (void)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock
                   startupError:(NSString **)startupError
{
  NSString *sdkName = _buildSettings[Xcode_SDK_NAME];
  NSAssert([sdkName hasPrefix:@"iphonesimulator"], @"Unexpected SDK: %@", sdkName);

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

  // Triggers some global state to be initialized - we must do this before
  // interacting with DTiPhoneSimulatorRemoteClient.
  [SimulatorLauncher loadAllPlatforms];

  void (^prepareSimulator)(BOOL freshSimulator, BOOL resetSimulator) = ^(BOOL freshSimulator, BOOL resetSimulator) {
    if (freshSimulator || resetSimulator) {
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
      ISHSDKInfo *sdkInfo = [[ISHDeviceVersions sharedInstance] sdkFromSDKRoot:[[self systemRootForSimulatedSdk] sdkRootPath]];
      if (RemoveSimulatorContentAndSettings([sdkInfo shortVersionString], [self cpuType], &removedPath, &removeError)) {
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
  };

  BOOL (^prepTestEnv)() = ^BOOL() {
    prepareSimulator(_freshSimulator, _resetSimulator);

    if (_freshInstall) {
      if (![self uninstallTestHostBundleID:testHostBundleID withError:startupError]) {
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
      prepareSimulator(YES, YES);
    }

    // Sometimes, the test host app installation retries are starting and
    // finishing in < 10 ms. That's way too fast for anything real to be
    // happening. To remedy this, we pause for a second between retries.
    [NSThread sleepForTimeInterval:1];
  }

  ReportStatusMessage(_reporters,
                      REPORTER_MESSAGE_INFO,
                      @"Launching test host and running tests ...");

  // Sometimes simulator or test host app fails to run.
  // Let's try several times to run before reporting about failure to callers.
  for (NSInteger remainingAttempts = kMaxRunTestsAttempts - 1; remainingAttempts >= 0; --remainingAttempts) {
    BOOL infraSucceeded = NO;
    NSError *error = nil;
    [self runTestsInSimulator:testHostAppPath
            feedOutputToBlock:outputLineBlock
               infraSucceeded:&infraSucceeded
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
                          REPORTER_MESSAGE_WARNING,
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
