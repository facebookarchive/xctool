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

#import "Testable.h"

@class SimulatorInfo, XcodeSubjectInfo;

/**
 * TestableExecutionInfo holds all the extra information we have to collect
 * in order to run a test bundle.
 */
@interface TestableExecutionInfo : NSObject

/**
 * The `Testable` this info belongs to.
 */
@property (nonatomic, strong) Testable *testable;

/**
 * The key/value pairs from `-showBuildSettings` for this testable.
 */
@property (nonatomic, copy) NSDictionary *buildSettings;

/**
 * Simulator info used to run the testable.
 */
@property (nonatomic, copy) SimulatorInfo *simulatorInfo;

/**
 * Will contain an error message if retrieving build settings with xcodebuild have failed
 */
@property (nonatomic, copy) NSString *buildSettingsError;

/**
 * A list of all test cases in the bundle, the form of:
 * ['SomeClass/testA', 'SomeClass/testB']
 *
 * These are fetched via otest-query.  May be nil if an error occurred.
 */
@property (nonatomic, copy) NSArray *testCases;

/**
 * Will contain an error message if `otest-query` fails.
 */
@property (nonatomic, copy) NSString *testCasesQueryError;

/**
 * Any arguments that should be passed to otest, with all macros expanded.
 */
@property (nonatomic, copy) NSArray *expandedArguments;

/**
 * Any environment that should be set for otest, with all macros expanded.
 */
@property (nonatomic, copy) NSDictionary *expandedEnvironment;

/**
 * Extracts testable build settings from an Xcode project.
 */
+ (NSDictionary *)testableBuildSettingsForProject:(NSString *)projectPath
                                           target:(NSString *)target
                                          objRoot:(NSString *)objRoot
                                          symRoot:(NSString *)symRoot
                                sharedPrecompsDir:(NSString *)sharedPrecompsDir
                             targetedDeviceFamily:(NSString *)targetedDeviceFamily
                                   xcodeArguments:(NSArray *)xcodeArguments
                                          testSDK:(NSString *)testSDK
                                            error:(NSString **)error;

/**
 * @return A populated TestableExecutionInfo instance.
 */
+ (instancetype)infoForTestable:(Testable *)testable
                  buildSettings:(NSDictionary *)buildSettings
                  simulatorInfo:(SimulatorInfo *)simulatorInfo;

@end
