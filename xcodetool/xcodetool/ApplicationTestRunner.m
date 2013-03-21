
#import "ApplicationTestRunner.h"
#import "XcodeToolUtil.h"
#import "SimulatorLauncher.h"
#import "LineReader.h"
#import <launch.h>

static void GetJobsIterator(const launch_data_t launch_data, const char *key, void *context) {
  void (^block)(const launch_data_t, const char *) = context;
  block(launch_data, key);
}

@implementation ApplicationTestRunner

- (DTiPhoneSimulatorSessionConfig *)sessionForAppUninstaller:(NSString *)bundleID
{
  assert(bundleID != nil);
  
  NSString *sdkVersion = [_buildSettings[@"SDK_NAME"] stringByReplacingOccurrencesOfString:@"iphonesimulator" withString:@""];
  DTiPhoneSimulatorSystemRoot *systemRoot = [DTiPhoneSimulatorSystemRoot rootWithSDKVersion:sdkVersion];
  DTiPhoneSimulatorApplicationSpecifier *appSpec = [DTiPhoneSimulatorApplicationSpecifier specifierWithApplicationPath:
                                                    [PathToFBXcodetoolBinaries() stringByAppendingPathComponent:@"app-uninstaller.app"]];
  DTiPhoneSimulatorSessionConfig *sessionConfig = [[[DTiPhoneSimulatorSessionConfig alloc] init] autorelease];
  [sessionConfig setApplicationToSimulateOnStart:appSpec];
  [sessionConfig setSimulatedSystemRoot:systemRoot];
  // Always run as iPhone (family = 1)
  [sessionConfig setSimulatedDeviceFamily:@1];
  [sessionConfig setSimulatedApplicationShouldWaitForDebugger:NO];
  [sessionConfig setLocalizedClientName:@"xcodetool"];
  [sessionConfig setSimulatedApplicationLaunchArgs:@[bundleID]];
  return sessionConfig;
}

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
  
  [sessionConfig setSimulatedApplicationLaunchArgs:@[
   @"-NSTreatUnknownArgumentsAsOpen", @"NO",
   @"-SenTestInvertScope", _senTestInvertScope ? @"YES" : @"NO",
   @"-SenTest", _senTestList,
   ]];
  NSMutableDictionary *launchEnvironment = [NSMutableDictionary dictionaryWithDictionary:@{
                                            @"CFFIXED_USER_HOME" : appSupportDir,
                                            @"DYLD_FRAMEWORK_PATH" : _buildSettings[@"TARGET_BUILD_DIR"],
                                            @"DYLD_LIBRARY_PATH" : _buildSettings[@"TARGET_BUILD_DIR"],
                                            @"DYLD_INSERT_LIBRARIES" : [@[
                                                                        [PathToFBXcodetoolBinaries() stringByAppendingPathComponent:@"otest-lib-ios.dylib"],
                                                                        ideBundleInjectionLibPath,
                                                                        ] componentsJoinedByString:@":"],
                                            @"DYLD_ROOT_PATH" : _buildSettings[@"SDKROOT"],
                                            @"IPHONE_SIMULATOR_ROOT" : _buildSettings[@"SDKROOT"],
                                            @"NSUnbufferedIO" : @"YES",
                                            @"XCInjectBundle" : testBundlePath,
                                            @"XCInjectBundleInto" : testHostPath,
                                            }];
  [launchEnvironment addEntriesFromDictionary:environment];
  [sessionConfig setSimulatedApplicationLaunchEnvironment:launchEnvironment];
  [sessionConfig setSimulatedApplicationStdOutPath:outputPath];
  [sessionConfig setSimulatedApplicationStdErrPath:outputPath];
  
  //[sessionConfig setLocalizedClientName:[NSString stringWithFormat:@"1234"]];
  [sessionConfig setLocalizedClientName:[NSString stringWithUTF8String:getprogname()]];
  
  return sessionConfig;
}

- (BOOL)uninstallApplication:(NSString *)bundleID
{
  assert(bundleID != nil);
  DTiPhoneSimulatorSessionConfig *config = [self sessionForAppUninstaller:bundleID];
  SimulatorLauncher *launcher = [[[SimulatorLauncher alloc] initWithSessionConfig:config] autorelease];

  return [launcher launchAndWaitForExit];
}

- (BOOL)runTestsInSimulator:(NSString *)testHostAppPath
{
  NSString *exitModePath = MakeTempFileWithPrefix(@"exit-mode");
  NSString *outputPath = MakeTempFileWithPrefix(@"output");
  NSFileHandle *outputHandle = [NSFileHandle fileHandleForReadingAtPath:outputPath];
  
  LineReader *reader = [[[LineReader alloc] initWithFileHandle:outputHandle] autorelease];
  reader.didReadLineBlock = ^(NSString *line){
    [_reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:line];
  };

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

+ (void)removeAllSimulatorJobs
{
  // Fully cleanup the simulator.  Just killing the simulator process itself isn't always itself.
  // In fact, when the simulator first starts up, it will try and remove any lingering launchd jobs
  // left over from the previous run.
  launch_data_t getJobsMessage = launch_data_new_string(LAUNCH_KEY_GETJOBS);
  launch_data_t response = launch_msg(getJobsMessage);
  
  assert(launch_data_get_type(response) == LAUNCH_DATA_DICTIONARY);
  
  launch_data_dict_iterate(response, GetJobsIterator, ^(const launch_data_t launch_data, const char *keyCString){
    NSString *key = [NSString stringWithCString:keyCString encoding:NSUTF8StringEncoding];
    
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
      launch_data_dict_insert(stopMessage, launch_data_new_string([key UTF8String]), LAUNCH_KEY_REMOVEJOB);
      launch_data_t stopResponse = launch_msg(stopMessage);
      
      launch_data_free(stopMessage);
      launch_data_free(stopResponse);
    }
  });

  launch_data_free(response);
  launch_data_free(getJobsMessage);
}

- (BOOL)runTests {
  BOOL succeeded = YES;
  NSString *failureReason = nil;
  
  [_reporters makeObjectsPerformSelector:@selector(handleEvent:)
                              withObject:StringForJSON(@{
                                                       @"event": @"begin-octest",
                                                       @"title": _buildSettings[@"FULL_PRODUCT_NAME"],
                                                       @"titleExtra": _buildSettings[@"SDK_NAME"],
                                                       })];
  
  // Sometimes the TEST_HOST will be wrapped in double quotes.
  NSString *testHostPath = [_buildSettings[@"TEST_HOST"] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
  NSString *testHostAppPath = [testHostPath stringByDeletingLastPathComponent];
  NSString *testHostPlistPath = [[testHostPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Info.plist"];
  NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:testHostPlistPath];
  NSString *testHostBundleID = plist[@"CFBundleIdentifier"];

  if (![self uninstallApplication:testHostBundleID]) {
    succeeded = NO;
    failureReason = [NSString stringWithFormat:@"Failed to uninstall the test host app '%@' before running tests.", testHostBundleID];
    goto Error;
  }
  
  if (![self runTestsInSimulator:testHostAppPath]) {
    succeeded = NO;
    failureReason = [NSString stringWithFormat:@"Failed to run tests"];
    goto Error;
  }
  
Error:
  [_reporters makeObjectsPerformSelector:@selector(handleEvent:)
                              withObject:StringForJSON(@{
                                                       @"event": @"end-octest",
                                                       @"title": _buildSettings[@"FULL_PRODUCT_NAME"],
                                                       @"titleExtra": _buildSettings[@"SDK_NAME"],
                                                       @"succeeded" : @(succeeded),
                                                       @"failureReason" : failureReason != nil ? failureReason : [NSNull null],
                                                       })];
  return succeeded;
}


@end
