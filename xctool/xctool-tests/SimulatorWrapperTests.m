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

#import <XCTest/XCTest.h>

#import "EventBuffer.h"
#import "FakeSimDevice.h"
#import "ReporterEvents.h"
#import "SimDevice.h"
#import "SimulatorWrapper.h"
#import "SimulatorWrapperXcode6.h"
#import "Swizzler.h"

@interface SimulatorWrapperTests : XCTestCase
{
  FakeSimDevice *_simDevice;

  NSWorkspace *_nsWorkspaceMock;
  id _runningApp;

  EventBuffer *_eventBuffer;
}
@end

@implementation SimulatorWrapperTests

- (void)setUp
{
  [super setUp];

  _simDevice = [FakeSimDevice new];
  _simDevice.fakeAvailable = YES;
  _simDevice.fakeUDID = [[NSUUID alloc] initWithUUIDString:@"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"];;
  _simDevice.fakeState = SimDeviceStateShutdown;

  _nsWorkspaceMock = mock([NSWorkspace class]);
  [[[given([_nsWorkspaceMock launchApplicationAtURL:anything() options:0 configuration:anything() error:nil])
    withMatcher:anything() forArgument:1]
    withMatcher:anything() forArgument:3]
    willDo:^id(NSInvocation *inv) {
    return _runningApp;
  }];

  _eventBuffer = [[EventBuffer alloc] init];
}

- (void)tearDown
{

  [super tearDown];
}

#pragma mark - Prepare

- (void)testPrepareSimulator
{
  SwizzleReceipt *swizzle = [Swizzler swizzleSelector:@selector(sharedWorkspace) forClass:[NSWorkspace class] withBlock:^(){
    return _nsWorkspaceMock;
  }];
  _runningApp = @0;
  _simDevice.fakeState = SimDeviceStateBooted;

  NSString *error = nil;
  BOOL result = [SimulatorWrapper prepareSimulator:_simDevice
                              newSimulatorInstance:NO
                                         reporters:@[_eventBuffer]
                                             error:&error];
  assertThatBool(result, isTrue());
  assertThat(error, nilValue());
  [Swizzler unswizzleFromReceipt:swizzle];

  NSArray *events = [_eventBuffer events];
  assertThatUnsignedInteger([events count], equalToUnsignedInt(2));
  assertThat(events[0][kReporter_BeginStatus_MessageKey], equalTo(@"Preparing 'Test Device' simulator to run tests ..."));
  assertThat(events[1][kReporter_EndStatus_MessageKey], equalTo(@"Prepared 'Test Device' simulator to run tests."));
}

- (void)testPrepareSimulatorFailsWithNoAppLaunched
{
  SwizzleReceipt *swizzle = [Swizzler swizzleSelector:@selector(sharedWorkspace) forClass:[NSWorkspace class] withBlock:^(){
    return _nsWorkspaceMock;
  }];

  NSString *error = nil;
  BOOL result = [SimulatorWrapper prepareSimulator:_simDevice
                              newSimulatorInstance:NO
                                         reporters:@[_eventBuffer]
                                             error:&error];
  assertThatBool(result, isFalse());
  assertThat(error, startsWith(@"iOS Simulator app wasn't launched at path"));
  [Swizzler unswizzleFromReceipt:swizzle];

  NSArray *events = [_eventBuffer events];
  assertThatUnsignedInteger([events count], equalToUnsignedInt(2));
  assertThat(events[0][kReporter_BeginStatus_MessageKey], equalTo(@"Preparing 'Test Device' simulator to run tests ..."));
  assertThat(events[1][kReporter_EndStatus_MessageKey], equalTo(@"Failed to prepare 'Test Device' simulator to run tests."));
}

- (void)testPrepareSimulatorTimesOut
{
  SwizzleReceipt *swizzle = [Swizzler swizzleSelector:@selector(sharedWorkspace) forClass:[NSWorkspace class] withBlock:^(){
    return _nsWorkspaceMock;
  }];
  _runningApp = @0;

  NSString *error = nil;
  BOOL result = [SimulatorWrapper prepareSimulator:_simDevice
                              newSimulatorInstance:NO
                                         reporters:@[_eventBuffer]
                                             error:&error];
  assertThatBool(result, isFalse());
  assertThat(error, startsWith(@"Timed out while waiting simulator to boot."));
  [Swizzler unswizzleFromReceipt:swizzle];

  NSArray *events = [_eventBuffer events];
  assertThatUnsignedInteger([events count], equalToUnsignedInt(2));
  assertThat(events[0][kReporter_BeginStatus_MessageKey], equalTo(@"Preparing 'Test Device' simulator to run tests ..."));
  assertThat(events[1][kReporter_EndStatus_MessageKey], equalTo(@"Failed to prepare 'Test Device' simulator to run tests."));
}

#pragma mark - Uninstall

- (void)testUninstallTestHostBundleID
{
  NSString *testHostBundleID = @"com.facebook.xctool-test-app";
  NSString *error = nil;
  [_simDevice addFakeInstalledApp:testHostBundleID];
  BOOL result = [SimulatorWrapper uninstallTestHostBundleID:testHostBundleID
                                                     device:_simDevice
                                                  reporters:@[_eventBuffer]
                                                      error:&error];
  assertThatBool(result, isTrue());
  assertThat(error, nilValue());

  NSArray *events = [_eventBuffer events];
  assertThatUnsignedInteger([events count], equalToUnsignedInt(2));
  assertThat(events[0][kReporter_BeginStatus_MessageKey], equalTo(@"Uninstalling 'com.facebook.xctool-test-app' to get a fresh install ..."));
  assertThat(events[1][kReporter_EndStatus_MessageKey], equalTo(@"Uninstalled 'com.facebook.xctool-test-app' to get a fresh install."));
}

- (void)testUninstallTestHostBundleIDAppNotInstalled
{
  NSString *testHostBundleID = @"com.facebook.xctool-test-app";
  NSString *error = nil;
  BOOL result = [SimulatorWrapper uninstallTestHostBundleID:testHostBundleID
                                                     device:_simDevice
                                                  reporters:@[_eventBuffer]
                                                      error:&error];
  assertThatBool(result, isTrue());
  assertThat(error, nilValue());

  NSArray *events = [_eventBuffer events];
  assertThatUnsignedInteger([events count], equalToUnsignedInt(2));
  assertThat(events[0][kReporter_BeginStatus_MessageKey], equalTo(@"Uninstalling 'com.facebook.xctool-test-app' to get a fresh install ..."));
  assertThat(events[1][kReporter_EndStatus_MessageKey], equalTo(@"Uninstalled 'com.facebook.xctool-test-app' to get a fresh install."));
}

- (void)testUninstallTestHostBundleIDFailure
{
  NSString *testHostBundleID = @"com.facebook.xctool-test-app";
  NSString *error = nil;
  [_simDevice addFakeInstalledApp:testHostBundleID];
  _simDevice.fakeUninstallFailure = YES;
  BOOL result = [SimulatorWrapper uninstallTestHostBundleID:testHostBundleID
                                                     device:_simDevice
                                                  reporters:@[_eventBuffer]
                                                      error:&error];
  assertThatBool(result, isFalse());
  assertThat(error, equalTo(@"Failed to uninstall the test host app 'com.facebook.xctool-test-app': Failed for unknown reason."));

  NSArray *events = [_eventBuffer events];
  assertThatUnsignedInteger([events count], equalToUnsignedInt(2));
  assertThat(events[0][kReporter_BeginStatus_MessageKey], equalTo(@"Uninstalling 'com.facebook.xctool-test-app' to get a fresh install ..."));
  assertThat(events[1][kReporter_EndStatus_MessageKey], equalTo(@"Failed to uninstall the test host app 'com.facebook.xctool-test-app'."));
}

- (void)testUninstallTestHostBundleIDTimesOut
{
  NSString *testHostBundleID = @"com.facebook.xctool-test-app";
  NSString *error = nil;
  [_simDevice addFakeInstalledApp:testHostBundleID];
  _simDevice.fakeUninstallTimeout = 20;
  BOOL result = [SimulatorWrapper uninstallTestHostBundleID:testHostBundleID
                                                     device:_simDevice
                                                  reporters:@[_eventBuffer]
                                                      error:&error];
  assertThatBool(result, isFalse());
  assertThat(error, equalTo(@"Failed to uninstall the test host app 'com.facebook.xctool-test-app': Timed out."));

  NSArray *events = [_eventBuffer events];
  assertThatUnsignedInteger([events count], equalToUnsignedInt(2));
  assertThat(events[0][kReporter_BeginStatus_MessageKey], equalTo(@"Uninstalling 'com.facebook.xctool-test-app' to get a fresh install ..."));
  assertThat(events[1][kReporter_EndStatus_MessageKey], equalTo(@"Failed to uninstall the test host app 'com.facebook.xctool-test-app'."));
}

- (void)testUninstallTestHostBundleIDTimesOutOnIsInstallCheck
{
  NSString *testHostBundleID = @"com.facebook.xctool-test-app";
  NSString *error = nil;
  [_simDevice addFakeInstalledApp:testHostBundleID];
  _simDevice.fakeIsInstalledTimeout = 20;
  BOOL result = [SimulatorWrapper uninstallTestHostBundleID:testHostBundleID
                                                     device:_simDevice
                                                  reporters:@[_eventBuffer]
                                                      error:&error];
  assertThatBool(result, isTrue());
  assertThat(error, nilValue());

  NSArray *events = [_eventBuffer events];
  assertThatUnsignedInteger([events count], equalToUnsignedInt(2));
  assertThat(events[0][kReporter_BeginStatus_MessageKey], equalTo(@"Uninstalling 'com.facebook.xctool-test-app' to get a fresh install ..."));
  assertThat(events[1][kReporter_EndStatus_MessageKey], equalTo(@"Uninstalled 'com.facebook.xctool-test-app' to get a fresh install."));
}

#pragma mark - Install

- (void)testInstallTestHostBundleID
{
  NSString *testHostBundleID = @"com.facebook.xctool-test-app";
  NSString *error = nil;
  BOOL result = [SimulatorWrapper installTestHostBundleID:testHostBundleID
                                           fromBundlePath:@"/tmp"
                                                   device:_simDevice
                                                reporters:@[_eventBuffer]
                                                    error:&error];
  assertThatBool(result, isTrue());
  assertThat(error, nilValue());


  NSArray *events = [_eventBuffer events];
  assertThatUnsignedInteger([events count], equalToUnsignedInt(2));
  assertThat(events[0][kReporter_BeginStatus_MessageKey], equalTo(@"Installing 'com.facebook.xctool-test-app' ..."));
  assertThat(events[1][kReporter_EndStatus_MessageKey], equalTo(@"Installed 'com.facebook.xctool-test-app'."));
}

- (void)testInstallTestHostBundleIDFailure
{
  NSString *testHostBundleID = @"com.facebook.xctool-test-app";
  NSString *error = nil;
  _simDevice.fakeInstallFailure = YES;
  BOOL result = [SimulatorWrapper installTestHostBundleID:testHostBundleID
                                           fromBundlePath:@"/tmp"
                                                   device:_simDevice
                                                reporters:@[_eventBuffer]
                                                    error:&error];
  assertThatBool(result, isFalse());
  assertThat(error, equalTo(@"Failed to install the test host app 'com.facebook.xctool-test-app': Failed for unknown reason."));


  NSArray *events = [_eventBuffer events];
  assertThatUnsignedInteger([events count], equalToUnsignedInt(2));
  assertThat(events[0][kReporter_BeginStatus_MessageKey], equalTo(@"Installing 'com.facebook.xctool-test-app' ..."));
  assertThat(events[1][kReporter_EndStatus_MessageKey], equalTo(@"Failed to install the test host app 'com.facebook.xctool-test-app'."));
}

- (void)testInstallTestHostBundleIDTimesOut
{
  NSString *testHostBundleID = @"com.facebook.xctool-test-app";
  NSString *error = nil;
  _simDevice.fakeInstallFailure = YES;
  _simDevice.fakeInstallTimeout = 20;
  BOOL result = [SimulatorWrapper installTestHostBundleID:testHostBundleID
                                           fromBundlePath:@"/tmp"
                                                   device:_simDevice
                                                reporters:@[_eventBuffer]
                                                    error:&error];
  assertThatBool(result, isFalse());
  assertThat(error, equalTo(@"Failed to install the test host app 'com.facebook.xctool-test-app': Timed out."));


  NSArray *events = [_eventBuffer events];
  assertThatUnsignedInteger([events count], equalToUnsignedInt(2));
  assertThat(events[0][kReporter_BeginStatus_MessageKey], equalTo(@"Installing 'com.facebook.xctool-test-app' ..."));
  assertThat(events[1][kReporter_EndStatus_MessageKey], equalTo(@"Failed to install the test host app 'com.facebook.xctool-test-app'."));
}

@end
