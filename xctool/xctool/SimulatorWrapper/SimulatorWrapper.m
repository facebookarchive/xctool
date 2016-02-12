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

#import <sys/stat.h>

#import "EventGenerator.h"
#import "ReportStatus.h"
#import "SimDevice.h"
#import "SimulatorInfo.h"
#import "SimulatorUtils.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

static const NSString * kOtestShimStdoutFilePath = @"OTEST_SHIM_STDOUT_FILE";
static const NSString * kOtestShimStderrFilePath __unused = @"OTEST_SHIM_STDERR_FILE";

static const NSString * kOptionsArgumentsKey = @"arguments";
static const NSString * kOptionsEnvironmentKey = @"environment";
static const NSString * kOptionsStderrKey = @"stderr";
static const NSString * kOptionsStdoutKey = @"stdout";
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
      feedOutputToBlock:(FdOutputLineFeedBlock)feedOutputToBlock
              reporters:(NSArray *)reporters
                  error:(NSError **)error
{
  int mkfifoResult;

  NSString *otestShimOutputPath = MakeTempFileWithPrefix(@"otestShimOutput");
  [[NSFileManager defaultManager] removeItemAtPath:otestShimOutputPath error:nil];
  mkfifoResult = mkfifo([otestShimOutputPath UTF8String], S_IWUSR | S_IRUSR | S_IRGRP);
  NSCAssert(mkfifoResult == 0, @"Failed to create a fifo at path: %@", otestShimOutputPath);

  // intercept stdout, stderr and post as simulator-output events
  NSString *simStdoutPath = MakeTempFileInDirectoryWithPrefix(device.dataPath, @"tmp/stdout_err");
  NSString *simStdoutRelativePath = [simStdoutPath substringFromIndex:device.dataPath.length];
  [[NSFileManager defaultManager] removeItemAtPath:simStdoutPath error:nil];
  mkfifoResult = mkfifo([simStdoutPath UTF8String], S_IWUSR | S_IRUSR | S_IRGRP);
  NSCAssert(mkfifoResult == 0, @"Failed to create a fifo at path: %@", simStdoutPath);

  NSMutableDictionary *environmentEdited = [environment mutableCopy];
  environmentEdited[kOtestShimStdoutFilePath] = otestShimOutputPath;

  /*
   * Passing the same set of arguments and environment as Xcode 6.4.
   */
  __block NSError *launchError = nil;
  NSDictionary *options = @{
    kOptionsArgumentsKey: arguments,
    kOptionsEnvironmentKey: environmentEdited,
    // stdout and stderr is forwarded to the same pipe
    // that way xctool preserves an order of printed lines
    kOptionsStdoutKey: simStdoutRelativePath,
    kOptionsStderrKey: simStdoutRelativePath,
    kOptionsWaitForDebuggerKey: @"0",
  };

  ReportStatusMessageBegin(reporters,
                           REPORTER_MESSAGE_INFO,
                           @"Launching '%@' on '%@' ...",
                           testHostBundleID,
                           device.name);
  __block pid_t appPID = -1;
  if (!RunSimulatorBlockWithTimeout(^{
    appPID = [device launchApplicationWithID:testHostBundleID
                                     options:options
                                       error:&launchError];
  })) {
    launchError = [NSError errorWithDomain:@"com.facebook.xctool.sim.launch.timeout"
                                      code:0
                                  userInfo:@{
      NSLocalizedDescriptionKey: @"Timed out while launching an application",
    }];
  }
  if (appPID == -1) {
    *error = launchError;
    ReportStatusMessageEnd(reporters,
                     REPORTER_MESSAGE_INFO,
                     @"Failed to launch '%@' on '%@': %@",
                     testHostBundleID,
                     device.name,
                     launchError.localizedDescription);
    return NO;
  }

  ReportStatusMessageEnd(reporters,
                       REPORTER_MESSAGE_INFO,
                       @"Launched '%@' on '%@'.",
                       testHostBundleID,
                       device.name);

  dispatch_semaphore_t appSemaphore = dispatch_semaphore_create(0);
  dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, appPID, DISPATCH_PROC_EXIT, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
  dispatch_source_set_event_handler(source, ^{
    dispatch_source_cancel(source);
  });
  dispatch_source_set_cancel_handler(source, ^{
    dispatch_semaphore_signal(appSemaphore);
  });
  dispatch_resume(source);

  int otestShimOutputReadFD = open([otestShimOutputPath UTF8String], O_RDONLY);
  int simStdoutReadFD = open([simStdoutPath UTF8String], O_RDONLY);
  int fildes[2] = {simStdoutReadFD, otestShimOutputReadFD};
  dispatch_queue_t feedQueue = dispatch_queue_create("com.facebook.simulator_wrapper.feed", DISPATCH_QUEUE_SERIAL);
  ReadOutputsAndFeedOuputLinesToBlockOnQueue(fildes, 2, ^(int fd, NSString *line) {
    if (fd != otestShimOutputReadFD) {
      NSDictionary *event = EventDictionaryWithNameAndContent(
        kReporter_Events_SimulatorOuput,
        @{kReporter_SimulatorOutput_OutputKey: StripAnsi([line stringByAppendingString:@"\n"])}
      );
      NSData *data = [NSJSONSerialization dataWithJSONObject:event options:0 error:nil];
      line = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    if (line) {
      feedOutputToBlock(fd, line);
    }
  },
  // all events should be processed serially on the same queue
  feedQueue,
  ^{
    dispatch_semaphore_wait(appSemaphore, DISPATCH_TIME_FOREVER);
  },
  // simulator app doesn't close pipes properly so xctool
  // shouldn't wait for them to be closed after the app exits
  NO);

  return  YES;
}

#pragma mark Installation Methods

+ (BOOL)prepareSimulator:(SimDevice *)device
    newSimulatorInstance:(BOOL)newSimulatorInstance
               reporters:(NSArray *)reporters
                   error:(NSString **)error
{
  ReportStatusMessageBegin(reporters,
                           REPORTER_MESSAGE_INFO,
                           @"Preparing '%@' simulator to run tests ...",
                           device.name);

  BOOL prepared = [[self classBasedOnCurrentVersionOfXcode] prepareSimulator:device
                                                        newSimulatorInstance:newSimulatorInstance
                                                                   reporters:reporters
                                                                       error:error];
  if (prepared) {
    ReportStatusMessageEnd(reporters,
                           REPORTER_MESSAGE_INFO,
                           @"Prepared '%@' simulator to run tests.",
                           device.name);
  } else {
    ReportStatusMessageEnd(reporters,
                           REPORTER_MESSAGE_WARNING,
                           @"Failed to prepare '%@' simulator to run tests.",
                           device.name);
  }
  return prepared;
}

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
                           @"Failed to uninstall the test host app '%@'.",
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
                           @"Failed to install the test host app '%@'.",
                           testHostBundleID);
  }
  return installed;
}

@end
