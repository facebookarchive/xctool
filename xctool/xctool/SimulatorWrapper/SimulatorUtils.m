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

#import "SimulatorUtils.h"

#import <launch.h>

#import "SimDevice.h"
#import "SimulatorInfo.h"
#import "SimVerifier.h"
#import "XCToolUtil.h"

static const dispatch_time_t kDefaultSimulatorBlockTimeout = 30;

static void GetJobsIterator(const launch_data_t launch_data, const char *key, void *context) {
  void (^block)(const launch_data_t, const char *) = (__bridge void (^)(const launch_data_t, const char *))(context);
  block(launch_data, key);
}

void StopAndRemoveLaunchdJob(NSString *job)
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
  NSArray *strings = @[
    @"UIKitApplication",
    @"SimulatorBridge",
    @"Simulator",
  ];

  NSArray *ignoreStrings = @[
    @"CoreSimulator",
  ];

  launch_data_t getJobsMessage = launch_data_new_string(LAUNCH_KEY_GETJOBS);
  launch_data_t response = launch_msg(getJobsMessage);

  NSCAssert(launch_data_get_type(response) == LAUNCH_DATA_DICTIONARY, @"Response is of unexpected type: %d", launch_data_get_type(response));

  NSMutableArray *jobs = [NSMutableArray array];

  launch_data_dict_iterate(response,
                           GetJobsIterator,
                           (__bridge void *)(^(const launch_data_t launch_data, const char *keyCString)
                           {
                             NSString *key = @(keyCString);

                             __block BOOL matches = NO;
                             [ignoreStrings enumerateObjectsUsingBlock:^(NSString *string, NSUInteger idx, BOOL *stop) {
                               if ([key rangeOfString:string options:NSCaseInsensitiveSearch].length > 0) {
                                 matches = YES;
                                 *stop = YES;
                               }
                             }];
                             if (matches) {
                               return;
                             }

                             [strings enumerateObjectsUsingBlock:^(NSString *string, NSUInteger idx, BOOL *stop) {
                               if ([key rangeOfString:string options:NSCaseInsensitiveSearch].length > 0) {
                                 matches = YES;
                                 *stop = YES;
                               }
                             }];

                             if (matches) {
                               [jobs addObject:key];
                             }
                           }));

  launch_data_free(response);
  launch_data_free(getJobsMessage);

  return jobs;
}

void KillSimulatorJobs()
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

BOOL RemoveSimulatorContentAndSettingsFolder(NSString *simulatorVersion, cpu_type_t cpuType, NSString **removedPath, NSString **errorMessage)
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

BOOL RemoveSimulatorContentAndSettings(SimulatorInfo *simulatorInfo, NSString **removedPath, NSString **errorMessage)
{
  SimDevice *simulatedDevice = [simulatorInfo simulatedDevice];
  __block NSError *error = nil;
  __block BOOL erased = NO;
  *removedPath = [simulatedDevice dataPath];
  if (!RunSimulatorBlockWithTimeout(^{
    erased = [simulatedDevice eraseContentsAndSettingsWithError:&error];
  })) {
    error = [NSError errorWithDomain:@"com.facebook.xctool.sim.erase.timeout"
                                code:0
                            userInfo:@{
      NSLocalizedDescriptionKey: @"Timed out while erasing contents and settings of a simulator.",
    }];
  }

  if (!erased) {
    *errorMessage = [NSString stringWithFormat:@"%@; %@.",
                     error.localizedDescription ?: @"Unknown error.",
                     [error.userInfo[NSUnderlyingErrorKey] localizedDescription] ?: @""];
  }
  return erased;
}

BOOL VerifySimulators(NSString **errorMessage)
{
  if (!NSClassFromString(@"SimVerifier")) {
    *errorMessage = [NSString stringWithFormat:@"SimVerifier class is not available."];
    return NO;
  }

  NSError *error = nil;
  BOOL result = [[SimVerifier sharedVerifier] verifyAllWithError:&error];
  if (!result || error) {
    *errorMessage = [NSString stringWithFormat:@"%@; %@.",
                     error.localizedDescription ?: @"Unknown error.",
                     [error.userInfo[NSUnderlyingErrorKey] localizedDescription] ?: @""];
  }
  return result;
}

BOOL ShutdownSimulator(SimulatorInfo *simulatorInfo, NSString **errorMessage)
{
  SimDevice *simulatedDevice = [simulatorInfo simulatedDevice];

  /*
   * In Xcode 6 there is a `simBridgeDistantObject` property
   * value of which comes from `[NSConnection rootProxy]`.
   * When we kill the Simulator.app this object and/or connection
   * becomes invalid: it crashes when accessed with
   * "[NSMachPort sendBeforeDate:] destination port invalid".
   * Since value of this property is created lazily and is cached
   * a workaround here is to reset that object so it is recreated
   * along with `NSConnection` next time it is used.
   * In Xcode 7 there is no such property apparently but luckily
   * it handles Simulator.app kills more gracefully and doesn't
   * require xctool to reset device states.
   */
  if ([simulatedDevice respondsToSelector:@selector(setSimBridgeDistantObject:)]) {
    [simulatedDevice setSimBridgeDistantObject:nil];
  }

  if (simulatedDevice.state != SimDeviceStateShutdown) {
    __block NSError *error = nil;
    __block BOOL shutdown = NO;
    if (!RunSimulatorBlockWithTimeout(^{
      shutdown = [simulatedDevice shutdownWithError:&error];
    })) {
      error = [NSError errorWithDomain:@"com.facebook.xctool.sim.shutdown.timeout"
                                  code:0
                              userInfo:@{
        NSLocalizedDescriptionKey: @"Timed out.",
      }];
    }
    if (!shutdown) {
      *errorMessage = [NSString stringWithFormat:@"Tried to shutdown the simulator but failed: %@; %@.",
                       error.localizedDescription ?: @"Unknown error.",
                       [error.userInfo[NSUnderlyingErrorKey] localizedDescription] ?: @""];
      return NO;
    }
  }
  return YES;
}

BOOL RunSimulatorBlockWithTimeout(dispatch_block_t block)
{
  dispatch_time_t timeout = IsRunningUnderTest() ? 5 : kDefaultSimulatorBlockTimeout;
  dispatch_time_t timer = dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC);
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    block();
    dispatch_semaphore_signal(semaphore);
  });
  return dispatch_semaphore_wait(semaphore, timer) == 0;
}
