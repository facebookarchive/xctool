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

#import "Buildable.h"

@interface Testable : Buildable <NSCopying>

/**
 * Tests that are set to be skipped in the Xcode scheme.
 */
@property (nonatomic, copy) NSArray *skippedTests;

/**
 * The only tests that should be run (i.e. set by user via `-only` option).
 */
@property (nonatomic, copy) NSArray *onlyTests;

/**
 * YES if this testable was deselected in the Xcode scheme
 * (i.e. it gets skipped).
 */
@property (nonatomic, assign) BOOL skipped;

/**
 * Array of arguments to passed on the command-line to the test bundle.  These
 * are optionally set by the Xcode scheme.
 */
@property (nonatomic, copy) NSArray *arguments;

/**
 * Dictionary of environment variables to set before launching the test bundle.
 * These are optionally set by the Xcode scheme.
 */
@property (nonatomic, copy) NSDictionary *environment;

/**
 * If the "Expand Variables Based On" option is enabled in the Xcode scheme,
 * this is the path to the project that contains the selected target.
 */
@property (nonatomic, copy) NSString *macroExpansionProjectPath;

/**
 * If the "Expand Variables Based On" option is enabled in the Xcode scheme,
 * this is the name of the selected target.
 */
@property (nonatomic, copy) NSString *macroExpansionTarget;

@end
