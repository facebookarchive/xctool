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
#import "Reporter.h"
#import "SimulatorLauncher.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"

static void GetJobsIterator(const launch_data_t launch_data, const char *key, void *context) {
  void (^block)(const launch_data_t, const char *) = context;
  block(launch_data, key);
}

/**
 Kill any active simulator plus any other iOS services it started via launchd.
 */
static void KillSimulatorJobs()
{
  launch_data_t getJobsMessage = launch_data_new_string(LAUNCH_KEY_GETJOBS);
  launch_data_t response = launch_msg(getJobsMessage);

  assert(launch_data_get_type(response) == LAUNCH_DATA_DICTIONARY);

  launch_data_dict_iterate(response,
                           GetJobsIterator,
                           ^(const launch_data_t launch_data, const char *keyCString){
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
      launch_data_t stopMessage = launch_data_alloc(LAUNCH_DATA_DICTIONARY);
      launch_data_dict_insert(stopMessage,
                              launch_data_new_string([key UTF8String]),
                              LAUNCH_KEY_REMOVEJOB);
      launch_data_t stopResponse = launch_msg(stopMessage);

      launch_data_free(stopMessage);
      launch_data_free(stopResponse);
    }
  });

  launch_data_free(response);
  launch_data_free(getJobsMessage);
}

@implementation OCUnitIOSAppTestRunner

- (DTiPhoneSimulatorSessionConfig *)sessionConfigForRunningTestsWithEnvironment:(NSDictionary *)environment
                                                                     outputPath:(NSString *)outputPath
{
  NSString *testHostPath = [_buildSettings[@"TEST_HOST"] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
  NSString *testHostAppPath = [testHostPath stringByDeletingLastPathComponent];

  NSString *sdkVersion = [_buildSettings[@"SDK_NAME"] stringByReplacingOccurrencesOfString:@"iphonesimulator" withString:@""];
  NSString *appSupportDir = [NSString stringWithFormat:@"%@/Library/Application Support/iPhone Simulator/%@",
                             NSHomeDirectory(), sdkVersion];
  NSString *ideBundleInjectionLibPath = @"/../../Library/PrivateFrameworks/IDEBundleInjection.framework/IDEBundleInjection";
  NSString *testBundlePath = [NSString stringWithFormat:@"%@/%@", _buildSettings[@"BUILT_PRODUCTS_DIR"], _buildSettings[@"FULL_PRODUCT_NAME"]];

  DTiPhoneSimulatorSystemRoot *systemRoot = [DTiPhoneSimulatorSystemRoot rootWithSDKVersion:sdkVersion];
  DTiPhoneSimulatorApplicationSpecifier *appSpec =
  [DTiPhoneSimulatorApplicationSpecifier specifierWithApplicationPath:testHostAppPath];

  DTiPhoneSimulatorSessionConfig *sessionConfig = [[[DTiPhoneSimulatorSessionConfig alloc] init] autorelease];
  [sessionConfig setApplicationToSimulateOnStart:appSpec];
  [sessionConfig setSimulatedSystemRoot:systemRoot];
  // Always run as iPhone (family = 1)
  [sessionConfig setSimulatedDeviceFamily:@1];
  [sessionConfig setSimulatedApplicationShouldWaitForDebugger:NO];

  [sessionConfig setSimulatedApplicationLaunchArgs:[self otestArguments]];

  NSMutableDictionary *launchEnvironment = [NSMutableDictionary dictionary];
  [launchEnvironment addEntriesFromDictionary:environment];
  [launchEnvironment addEntriesFromDictionary:@{
   @"CFFIXED_USER_HOME" : appSupportDir,
   @"DYLD_FRAMEWORK_PATH" : _buildSettings[@"TARGET_BUILD_DIR"],
   @"DYLD_LIBRARY_PATH" : _buildSettings[@"TARGET_BUILD_DIR"],
   @"DYLD_INSERT_LIBRARIES" : [@[
                                 [PathToXCToolBinaries() stringByAppendingPathComponent:@"otest-shim-ios.dylib"],
                               ideBundleInjectionLibPath,
                               ] componentsJoinedByString:@":"],
   @"DYLD_ROOT_PATH" : _buildSettings[@"SDKROOT"],
   @"IPHONE_SIMULATOR_ROOT" : _buildSettings[@"SDKROOT"],
   @"NSUnbufferedIO" : @"YES",
   @"XCInjectBundle" : testBundlePath,
   @"XCInjectBundleInto" : testHostPath,
   }];
  [sessionConfig setSimulatedApplicationLaunchEnvironment:launchEnvironment];
  
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
                                                    [PathToXCToolBinaries() stringByAppendingPathComponent:@"mobile-installation-helper.app"]];
  DTiPhoneSimulatorSessionConfig *sessionConfig = [[[DTiPhoneSimulatorSessionConfig alloc] init] autorelease];
  [sessionConfig setApplicationToSimulateOnStart:appSpec];
  [sessionConfig setSimulatedSystemRoot:systemRoot];
  // Always run as iPhone (family = 1)
  [sessionConfig setSimulatedDeviceFamily:@1];
  [sessionConfig setSimulatedApplicationShouldWaitForDebugger:NO];
  [sessionConfig setLocalizedClientName:@"xctool"];
  [sessionConfig setSimulatedApplicationLaunchArgs:arguments];
  [sessionConfig setSimulatedApplicationLaunchEnvironment:@{}];

  SimulatorLauncher *launcher = [[[SimulatorLauncher alloc] initWithSessionConfig:sessionConfig] autorelease];

  return [launcher launchAndWaitForExit];
}

- (BOOL)runTestsInSimulator:(NSString *)testHostAppPath feedOutputToBlock:(void (^)(NSString *))feedOutputToBlock
{
  NSString *exitModePath = MakeTempFileWithPrefix(@"exit-mode");
  NSString *outputPath = MakeTempFileWithPrefix(@"output");
  NSFileHandle *outputHandle = [NSFileHandle fileHandleForReadingAtPath:outputPath];

  LineReader *reader = [[[LineReader alloc] initWithFileHandle:outputHandle] autorelease];
  reader.didReadLineBlock = feedOutputToBlock;

  DTiPhoneSimulatorSessionConfig *sessionConfig =
    [self sessionConfigForRunningTestsWithEnvironment:@{
     @"SAVE_EXIT_MODE_TO" : exitModePath,
     }
                                           outputPath:outputPath];

  [sessionConfig setSimulatedApplicationStdOutPath:outputPath];
  [sessionConfig setSimulatedApplicationStdErrPath:outputPath];

  SimulatorLauncher *launcher = [[[SimulatorLauncher alloc] initWithSessionConfig:sessionConfig] autorelease];

  [reader startReading];

  [launcher launchAndWaitForExit];

  [reader stopReading];
  [reader finishReadingToEndOfFile];

  NSDictionary *exitMode = [NSDictionary dictionaryWithContentsOfFile:exitModePath];

  [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
  [[NSFileManager defaultManager] removeItemAtPath:exitModePath error:nil];

  return [exitMode[@"via"] isEqualToString:@"exit"] && ([exitMode[@"status"] intValue] == 0);
}

- (BOOL)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock error:(NSString **)error
{
  NSString *sdkName = _buildSettings[@"SDK_NAME"];
  NSAssert([sdkName hasPrefix:@"iphonesimulator"], @"Unexpected SDK: %@", sdkName);

  // Sometimes the TEST_HOST will be wrapped in double quotes.
  NSString *testHostPath = [_buildSettings[@"TEST_HOST"] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
  NSString *testHostAppPath = [testHostPath stringByDeletingLastPathComponent];
  NSString *testHostPlistPath = [[testHostPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Info.plist"];
  NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:testHostPlistPath];
  NSString *testHostBundleID = plist[@"CFBundleIdentifier"];

  if (_freshSimulator) {
    ReportMessage(REPORTER_MESSAGE_INFO,
                  @"Stopping any existing iOS simulator jobs to get a "
                  @"fresh simulator.");
    KillSimulatorJobs();
  }

  if (_freshInstall) {
    ReportMessage(REPORTER_MESSAGE_INFO,
                  @"Uninstalling '%@' to get a fresh install.",
                  testHostBundleID);
    BOOL uninstalled = [self runMobileInstallationHelperWithArguments:@[
                        @"uninstall",
                        testHostBundleID,
                        ]];
    if (!uninstalled) {
      *error = [NSString stringWithFormat:
                @"Failed to uninstall the test host app '%@' "
                @"before running tests.",
                testHostBundleID];
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
  ReportMessage(REPORTER_MESSAGE_INFO, @"Installing '%@' ...", testHostAppPath);
  BOOL installed = [self runMobileInstallationHelperWithArguments:@[
                    @"install",
                    testHostAppPath,
                    ]];
  if (!installed) {
    *error = [NSString stringWithFormat:
              @"Failed to install the test host app '%@'.",
              testHostBundleID];
    return NO;
  }

  ReportMessage(REPORTER_MESSAGE_INFO,
                @"Launching test host and running tests...");
  if (![self runTestsInSimulator:testHostAppPath feedOutputToBlock:outputLineBlock]) {
    *error = [NSString stringWithFormat:@"Failed to run tests"];
    return NO;
  }

  return YES;
}

@end
