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

@interface LaunchHandlers : NSObject

/**
 * Returns a launch handler block that will fake out the -showBuildSettings
 * call for this project/scheme.
 */
+ (id)handlerForShowBuildSettingsWithProject:(NSString *)project
                                      scheme:(NSString *)scheme
                                settingsPath:(NSString *)settingsPath;

+ (id)handlerForShowBuildSettingsWithProject:(NSString *)project
                                      scheme:(NSString *)scheme
                                settingsPath:(NSString *)settingsPath
                                        hide:(BOOL)hide;

+ (id)handlerForShowBuildSettingsWithAction:(NSString *)action
                                    project:(NSString *)project
                                     scheme:(NSString *)scheme
                               settingsPath:(NSString *)settingsPath
                                       hide:(BOOL)hide;

+ (id)handlerForShowBuildSettingsWithProject:(NSString *)project
                                      target:(NSString *)target
                                settingsPath:(NSString *)settingsPath
                                        hide:(BOOL)hide;

+ (id)handlerForShowBuildSettingsErrorWithProject:(NSString *)project
                                           target:(NSString *)target
                                 errorMessagePath:(NSString *)errorMessagePath
                                             hide:(BOOL)hide;


/**
 * Returns a launch handler block that will fake out the -showBuildSettings
 * call for this workspace/scheme.
 */
+ (id)handlerForShowBuildSettingsWithWorkspace:(NSString *)workspace
                                        scheme:(NSString *)scheme
                                  settingsPath:(NSString *)settingsPath;

+ (id)handlerForShowBuildSettingsWithWorkspace:(NSString *)workspace
                                        scheme:(NSString *)scheme
                                  settingsPath:(NSString *)settingsPath
                                          hide:(BOOL)hide;

+ (id)handlerForOtestQueryReturningTestList:(NSArray *)testList;
+ (id)handlerForOtestQueryWithTestHost:(NSString *)testHost
                     returningTestList:(NSArray *)testList;

+ (id)handlerForSimctlXctestRunReturningTestEvents:(NSData *)testEvents;

@end
