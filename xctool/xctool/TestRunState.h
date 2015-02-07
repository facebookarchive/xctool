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

#import "XCTestEventState.h"
#import "XCTestSuiteEventState.h"
#import "Reporter.h"

@interface TestRunState : Reporter {
  XCTestSuiteEventState *_testSuiteState;
  XCTestEventState *_previousTestState;
  NSSet *_crashReportsAtStart;
  NSMutableString *_outputBeforeTestsStart;
}

@property (nonatomic, readonly) XCTestSuiteEventState *testSuiteState;

- (instancetype)initWithTests:(NSArray *)testList
                    reporters:(NSArray *)reporters;

- (instancetype)initWithTestSuiteEventState:(XCTestSuiteEventState *)suiteState;

- (BOOL)allTestsPassed;
- (void)prepareToRun;
- (void)didFinishRunWithStartupError:(NSString *)startupError otherErrors:(NSString *)otherErrors;

@end
