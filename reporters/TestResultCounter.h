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

/**
 * If tests are run with continueAfterFailure (the default) then it's possible
 * to get multiple assertion failures per test. So if we want to know how many
 * tests failed or errored we have the track the numbers ourselves rather than
 * rely on TotalFailureCountKey and friends
 */
@interface TestResultCounter : NSObject

- (void)suiteBegin;
- (void)suiteEnd;

- (void)testPassed;
- (void)testFailed;
- (void)testErrored;

@property (nonatomic, assign) NSUInteger suitePassed;
@property (nonatomic, assign) NSUInteger suiteFailed;
@property (nonatomic, assign) NSUInteger suiteErrored;
@property (nonatomic, assign) NSUInteger suiteTotal;
@property (nonatomic, assign) NSUInteger actionPassed;
@property (nonatomic, assign) NSUInteger actionFailed;
@property (nonatomic, assign) NSUInteger actionErrored;
@property (nonatomic, assign) NSUInteger actionTotal;

@end
