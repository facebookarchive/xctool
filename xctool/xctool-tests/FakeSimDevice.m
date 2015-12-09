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

#import "FakeSimDevice.h"

@interface FakeSimDevice ()
@property (nonatomic, strong) NSMutableSet *fakeInstalledApps;
@end

@implementation FakeSimDevice

- (instancetype)init
{
  self = [super init];
  if (self) {
    _fakeInstalledApps = [NSMutableSet set];
    _fakeInstallFailure = NO;
    _fakeUninstallFailure = NO;
    _fakeInstallTimeout = 0;
    _fakeUninstallTimeout = 0;
    _fakeIsInstalledTimeout = 0;
  }
  return self;
}

- (BOOL)available
{
  return _fakeAvailable;
}

- (NSString *)name
{
  return @"Test Device";
}

- (unsigned long long)state
{
  return _fakeState;
}

- (NSUUID *)UDID
{
  return _fakeUDID;
}

- (void)addFakeInstalledApp:(NSString *)testHostBundleID
{
  [_fakeInstalledApps addObject:testHostBundleID];
}

- (BOOL)applicationIsInstalled:(NSString *)bundleId type:(NSString **)arg2 error:(NSError **)error
{
  sleep(_fakeIsInstalledTimeout);
  return [_fakeInstalledApps containsObject:bundleId];
}

- (BOOL)uninstallApplication:(NSString *)bundleId withOptions:(NSDictionary *)options error:(NSError **)error
{
  sleep(_fakeUninstallTimeout);
  return !_fakeUninstallFailure;
}

- (BOOL)installApplication:(NSURL *)appURL withOptions:(NSDictionary *)options error:(NSError **)error
{
  sleep(_fakeInstallTimeout);
  return !_fakeInstallFailure;
}

@end
