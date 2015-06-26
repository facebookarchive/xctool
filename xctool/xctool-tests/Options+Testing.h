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

#import "Options.h"

@interface Options (Testing)

/**
 * Returns an Options object, initialized with the given arguments via
 * consumeArguments:.  Throws an exception if options do not parse.
 */
+ (Options *)optionsFrom:(NSArray *)arguments;

/**
 * Throws an exception if validateReporterOptions: fails.
 */
- (Options *)assertReporterOptionsValidate;

/**
 * Throws exception if reporter validation doesn't fail with
 * the given message.
 */
- (void)assertReporterOptionsFailToValidateWithError:(NSString *)message;

/**
 * Asserts that options fail validateOptions: with a given error.
 */
- (void)assertOptionsFailToValidateWithError:(NSString *)message;

/**
 * Asserts that options fail validateOptions: with a given error.
 * A fake XcodeSubjectInfo is given to validateOptions: populated
 * with build settings from the given path.
 */
- (void)assertOptionsFailToValidateWithError:(NSString *)message
                   withBuildSettingsFromFile:(NSString *)path;

/**
 * Assert that validation passes.  An empty XcodeSubjectInfo is given to
 * validateOptions:.
 */
- (Options *)assertOptionsValidate;

/**
 * Assert that validation passes.  A fake XcodeSubjectInfo is given to
 * validateOptions: populated with build settings from the given path.
 */
- (Options *)assertOptionsValidateWithBuildSettingsFromFile:(NSString *)path;

@end
