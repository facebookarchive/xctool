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

#import "OCTestEventState.h"
#import "OCTestSuiteEventState.h"
#import "Reporter.h"

@interface TestRunState : Reporter

@property (nonatomic, strong, readonly) OCTestSuiteEventState *testSuiteState;

- (instancetype)initWithTests:(NSArray *)testList
                    reporters:(NSArray *)reporters;

- (instancetype)initWithTestSuiteEventState:(OCTestSuiteEventState *)suiteState;

- (BOOL)allTestsPassed;
- (void)prepareToRun;
- (void)didFinishRunWithStartupError:(NSString *)startupError otherErrors:(NSString *)otherErrors;

@end
