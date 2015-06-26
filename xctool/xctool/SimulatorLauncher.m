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

#import "SimulatorLauncher.h"

static BOOL __didLoadAllPlatforms = NO;

// class-dump'ed from DVTFoundation
@interface DVTPlatform : NSObject

+ (BOOL)loadAllPlatformsReturningError:(NSError **)error;
+ (instancetype)platformForIdentifier:(NSString *)identifier;

@end

@interface SimulatorLauncher ()
@property (nonatomic, assign) BOOL didQuit;
@property (nonatomic, assign) BOOL didFailToStart;
@property (nonatomic, assign) BOOL didStart;
@property (nonatomic, strong) NSError *didEndWithError;
@property (nonatomic, strong) DTiPhoneSimulatorSession *session;
@property (nonatomic, strong) NSError *launchError;
@end

@implementation SimulatorLauncher

+ (void)loadAllPlatforms
{
  if (!__didLoadAllPlatforms) {
    NSError *error = nil;
    NSAssert([DVTPlatform loadAllPlatformsReturningError:&error],
             @"Failed to load all platforms: %@", error);

    // The following will fail if DVTPlatform hasn't loaded all platforms.
    NSAssert([DTiPhoneSimulatorSystemRoot knownRoots] != nil,
             @"DVTPlatform hasn't been initialized yet.");
    // DTiPhoneSimulatorRemoteClient will make this same call, so let's assert
    // that it's working.
    NSAssert([DVTPlatform platformForIdentifier:@"com.apple.platform.iphonesimulator"] != nil,
             @"DVTPlatform hasn't been initialized yet.");

    __didLoadAllPlatforms = YES;
  }
}

- (instancetype)initWithSessionConfig:(DTiPhoneSimulatorSessionConfig *)sessionConfig
                 deviceName:(NSString *)deviceName
{
  if (self = [super init]) {
    NSAssert(__didLoadAllPlatforms,
             @"Must call +[SimulatorLauncher loadAllPlatforms] before "
             @"interacting with DTiPhoneSimulatorRemoteClient.");

    // Set the device type if supplied
    if (deviceName) {
      CFPreferencesSetAppValue((CFStringRef)@"SimulateDevice", (__bridge CFPropertyListRef)deviceName, (CFStringRef)@"com.apple.iphonesimulator");
      CFPreferencesAppSynchronize((CFStringRef)@"com.apple.iphonesimulator");
    }

    _session = [[DTiPhoneSimulatorSession alloc] init];
    [_session setSessionConfig:sessionConfig];
    [_session setDelegate:self];
  }
  return self;
}

- (BOOL)launchAndWaitForExit
{
  NSError *error = nil;
  if (![_session requestStartWithConfig:[_session sessionConfig] timeout:[_launchTimeout intValue] error:&error]) {
    _launchError = error;
    return NO;
  }

  while (!_didQuit && !_didFailToStart) {
    CFRunLoopRun();
  }

  return _didStart;
}

- (BOOL)launchAndWaitForStart
{
  NSError *error = nil;
  if (![_session requestStartWithConfig:[_session sessionConfig] timeout:[_launchTimeout intValue] error:&error]) {
    _launchError = error;
    return NO;
  }

  while (!_didStart && !_didFailToStart) {
    CFRunLoopRun();
  }

  return _didStart;
}

- (void)session:(DTiPhoneSimulatorSession *)session didEndWithError:(NSError *)error
{
  if (error) {
    _didEndWithError = error;
  }
  _didQuit = YES;

  CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)session:(DTiPhoneSimulatorSession *)session didStart:(BOOL)started withError:(NSError *)error
{
  if (started) {
    _didStart = YES;
  } else {
    _launchError = error;
    _didFailToStart = YES;
  }

  CFRunLoopStop(CFRunLoopGetCurrent());
}

@end
