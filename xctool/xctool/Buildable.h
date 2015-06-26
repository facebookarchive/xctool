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

@interface Buildable : NSObject <NSCopying>

/**
 * Path to the project that contains this buildable's target.
 */
@property (nonatomic, copy) NSString *projectPath;

/**
 * Name of the target.
 */
@property (nonatomic, copy) NSString *target;

/**
 * The Xcode hash/ID for this target.
 */
@property (nonatomic, copy) NSString *targetID;

/**
 * Name of the target's executable
 */
@property (nonatomic, copy) NSString *executable;

/**
 * YES if this target as marked as Build for Run
 */
@property (nonatomic, assign) BOOL buildForRunning;

/**
 * YES if this target as marked as Build for Test
 */
@property (nonatomic, assign) BOOL buildForTesting;

/**
 * YES if this target as marked as Build for Analyze
 */
@property (nonatomic, assign) BOOL buildForAnalyzing;

@end
