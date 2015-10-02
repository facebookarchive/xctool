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

#import "OCEventState.h"

@interface OCTestEventState : OCEventState

@property (nonatomic, copy, readonly) NSString *className;
@property (nonatomic, copy, readonly) NSString *methodName;
@property (nonatomic, copy, readonly) NSString *result;
@property (nonatomic, readonly) BOOL isStarted;
@property (nonatomic, readonly) BOOL isFinished;
@property (nonatomic, readonly) BOOL isSuccessful;
@property (nonatomic, assign) double duration;


/**
 * @param Test name in the form of "ClassName/MethodName"
 * @param Reporters to publish to
 */
- (instancetype)initWithInputName:(NSString *)name
                        reporters:(NSArray *)reporters;

- (instancetype)initWithInputName:(NSString *)name;

- (NSString *)testName;
- (void)stateBeginTest;
- (void)stateEndTest:(BOOL)successful result:(NSString *)result;
- (void)stateEndTest:(BOOL)successful result:(NSString *)result duration:(double)duration;
- (void)stateTestOutput:(NSString *)output;
- (void)appendOutput:(NSString *)output;
- (void)publishOutput;
- (BOOL)isRunning;
- (NSString *)outputAlreadyPublished;

@end
