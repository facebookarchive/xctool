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
#import "OCTestEventState.h"

@interface OCTestSuiteEventState : OCEventState

@property (nonatomic, copy, readonly) NSString *testName;
@property (nonatomic, readonly) BOOL isStarted;
@property (nonatomic, readonly) BOOL isFinished;
@property (nonatomic, copy, readonly) NSMutableArray *tests;

- (instancetype)initWithName:(NSString *)name;
- (instancetype)initWithName:(NSString *)name
                   reporters:(NSArray *)reporters;

- (void)beginTestSuite:(NSDictionary *)event;
- (void)endTestSuite:(NSDictionary *)event;
- (void)insertTest:(OCTestEventState *)test atIndex:(NSUInteger)index;
- (void)addTest:(OCTestEventState *)test;
- (void)addTestsFromArray:(NSArray *)tests;
- (OCTestEventState *)runningTest;
- (NSArray *)unstartedTests;
- (NSArray *)finishedTests;
- (NSArray *)unfinishedTests;
- (OCTestEventState *)getTestWithTestName:(NSString *)name;
- (unsigned int)testCount;
- (unsigned int)totalFailures;
- (unsigned int)totalErrors;
- (double)testDuration;
- (double)totalDuration;

- (void)publishEventsForFinishedTests;

@end
