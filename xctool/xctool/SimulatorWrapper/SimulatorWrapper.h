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

#import <Foundation/Foundation.h>

#import "TaskUtil.h"

@class SimDevice;

@interface SimulatorWrapper : NSObject

/**
 * Use the CoreSimulator framework to start the app in the simulator,
 * inject otest-shim into the app as it starts, and feed line-by-line output to
 * the `feedOutputToBlock`.
 *
 * @param testHostAppID      Bundle ID of the test host app.
 * @param device             Device on which to run tests.
 * @param arguments          Arguments to pass to the test host app.
 * @param environment        Environment to set of the test host app.
 * @param feedOutputToBlock  The block is called once for every line of output.
 * @param testsSucceeded     If all tests ran and passed, this will be set to YES.
 *                           the tests, this will be set to YES.  Note that this
 *                           will be YES even if some tests failed.
 * @return YES, if we succeeded in launching the app.
 */
+ (BOOL)runHostAppTests:(NSString *)testHostBundleID
                 device:(SimDevice *)device
              arguments:(NSArray *)arguments
            environment:(NSDictionary *)environment
      feedOutputToBlock:(FdOutputLineFeedBlock)feedOutputToBlock
              reporters:(NSArray *)reporters
                  error:(NSError **)error;

+ (BOOL)prepareSimulator:(SimDevice *)device
    newSimulatorInstance:(BOOL)newSimulatorInstance
               reporters:(NSArray *)reporters
                   error:(NSString **)error;

+ (BOOL)uninstallTestHostBundleID:(NSString *)testHostBundleID
                           device:(SimDevice *)device
                        reporters:(NSArray *)reporters
                            error:(NSString **)error;

+ (BOOL)installTestHostBundleID:(NSString *)testHostBundleID
                 fromBundlePath:(NSString *)testHostBundlePath
                         device:(SimDevice *)device
                      reporters:(NSArray *)reporters
                          error:(NSString **)error;

@end
