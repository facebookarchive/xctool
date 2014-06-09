//
// Copyright 2014 Facebook
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

@class SimulatorInfo;

@interface SimulatorWrapper : NSObject

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
+ (void)runHostAppTests:(NSString *)testHostAppPath
          simulatorInfo:(SimulatorInfo *)simInfo
          appLaunchArgs:(NSArray *)launchArgs
   appLaunchEnvironment:(NSDictionary *)launchEnvironment
      feedOutputToBlock:(void (^)(NSString *))feedOutputToBlock
         infraSucceeded:(BOOL *)infraSucceeded
                  error:(NSError **)error;

+ (BOOL)uninstallTestHostBundleID:(NSString *)testHostBundleID
                    simulatorInfo:(SimulatorInfo *)simInfo
                        reporters:(NSArray *)reporters
                            error:(NSString **)error;

+ (BOOL)installTestHostBundleID:(NSString *)testHostBundleID
                 fromBundlePath:(NSString *)testHostBundlePath
                  simulatorInfo:(SimulatorInfo *)simInfo
                      reporters:(NSArray *)reporters
                          error:(NSString **)error;

@end
