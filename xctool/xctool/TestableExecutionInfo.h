//
// Copyright 2013 Facebook
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

@class XcodeSubjectInfo;

/**
 * TestableExecutionInfo holds all the extra information we have to collect
 * in order to run a test bundle.
 */
@interface TestableExecutionInfo : NSObject

/**
 * The `Testable` this info belongs to.
 */
@property (nonatomic, retain) Testable *testable;

/**
 * The key/value pairs from `-showBuildSettings` for this testable.
 */
@property (nonatomic, retain) NSDictionary *buildSettings;

/**
 * A list of all test cases in the bundle, the form of:
 * ['SomeClass/testA', 'SomeClass/testB']
 *
 * These are fetched via otest-query
 */
@property (nonatomic, retain) NSArray *testCases;

/**
 * Any arguments that should be passed to otest, with all macros expanded.
 */
@property (nonatomic, retain) NSArray *expandedArguments;

/**
 * Any environment that should be set for otest, with all macros expanded.
 */
@property (nonatomic, retain) NSDictionary *expandedEnvironment;

/**
 * @return A populated TestableExecutionInfo instance.
 */
+ (instancetype)infoForTestable:(Testable *)testable
               xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
            xcodebuildArguments:(NSArray *)xcodebuildArguments
                        testSDK:(NSString *)testSDK;

@end
