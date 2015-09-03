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

#import "SimulatorWrapper.h"
#import "SimulatorWrapperXcode6.h"

#import "LineReader.h"
#import "ReportStatus.h"
#import "SimDevice.h"
#import "SimulatorInfo.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

static const NSString * kOtestShimStdoutFilePath = @"OTEST_SHIM_STDOUT_FILE";
static const NSString * kOtestShimStderrFilePath __unused = @"OTEST_SHIM_STDERR_FILE";

static const NSString * kOptionsArgumentsKey = @"arguments";
static const NSString * kOptionsEnvironmentKey = @"environment";
static const NSString * kOptionsStderrKey = @"stderr";
static const NSString * kOptionsWaitForDebuggerKey = @"wait_for_debugger";

@implementation SimulatorWrapper

#pragma mark -
#pragma mark Helpers

+ (Class)classBasedOnCurrentVersionOfXcode
{
  return [SimulatorWrapperXcode6 class];
}

#pragma mark -
#pragma mark Running App Methods

+ (BOOL)runHostAppTests:(NSString *)testHostBundleID
                 device:(SimDevice *)device
              arguments:(NSArray *)arguments
            environment:(NSDictionary *)environment
      feedOutputToBlock:(void (^)(NSString *))feedOutputToBlock
                  error:(NSError **)error
{
  NSString *outputPath = MakeTempFileWithPrefix(@"output");
  NSFileHandle *outputHandle = [NSFileHandle fileHandleForReadingAtPath:outputPath];

  LineReader *reader = [[LineReader alloc] initWithFileHandle:outputHandle];
  reader.didReadLineBlock = feedOutputToBlock;

  NSMutableDictionary *environmentEdited = [environment mutableCopy];
  environmentEdited[kOtestShimStdoutFilePath] = outputPath;

  /*
   * Passing the same set of arguments and environment as Xcode 6.4.
   */
  NSError *launchError = nil;
  NSDictionary *options = @{
    kOptionsArgumentsKey: arguments,
    kOptionsEnvironmentKey: environmentEdited,
    // Don't let anything from STDERR get in our stream.  Normally, once
    // otest-shim gets loaded, we don't have to worry about whatever is coming
    // over STDERR since the shim will redirect all output (including STDERR) into
    // JSON outout on STDOUT.
    //
    // But, even before otest-shim loads, there's a chance something else may spew
    // into STDERR.  This happened in --
    // https://github.com/facebook/xctool/issues/224#issuecomment-29288004
    kOptionsStderrKey: @"/dev/null",
    kOptionsWaitForDebuggerKey: @"1",
  };

  pid_t appPID = [device launchApplicationWithID:testHostBundleID
                                         options:options
                                           error:&launchError];
  if (appPID == -1) {
    *error = launchError;
    return NO;
  }

  dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, appPID, DISPATCH_PROC_EXIT, dispatch_get_main_queue());
  dispatch_source_set_event_handler(source, ^{
    dispatch_source_cancel(source);
  });
  dispatch_source_set_cancel_handler(source, ^{
    CFRunLoopStop(CFRunLoopGetCurrent());
  });
  dispatch_resume(source);

  [reader startReading];

  while (dispatch_source_testcancel(source) == 0) {
    CFRunLoopRun();
  }

  [reader stopReading];
  [reader finishReadingToEndOfFile];
  return  YES;
}

#pragma mark Installation Methods

+ (BOOL)uninstallTestHostBundleID:(NSString *)testHostBundleID
                           device:(SimDevice *)device
                        reporters:(NSArray *)reporters
                            error:(NSString **)error
{
  ReportStatusMessageBegin(reporters,
                           REPORTER_MESSAGE_INFO,
                           @"Uninstalling '%@' to get a fresh install ...",
                           testHostBundleID);

  BOOL uninstalled = [[self classBasedOnCurrentVersionOfXcode] uninstallTestHostBundleID:testHostBundleID
                                                                                  device:device
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
                         device:(SimDevice *)device
                      reporters:(NSArray *)reporters
                          error:(NSString **)error
{
  ReportStatusMessageBegin(reporters,
                           REPORTER_MESSAGE_INFO,
                           @"Installing '%@' ...",
                           testHostBundleID);

  BOOL installed = [[self classBasedOnCurrentVersionOfXcode] installTestHostBundleID:testHostBundleID
                                                                      fromBundlePath:testHostBundlePath
                                                                              device:device
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
