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

#import "OCTestSuiteEventState.h"

#import "EventGenerator.h"
#import "ReporterEvents.h"

@interface OCTestSuiteEventState ()
@property (nonatomic, assign) double totalDuration;
@property (nonatomic, copy) NSDictionary *beginTestSuiteInfo;
@end

@implementation OCTestSuiteEventState

- (instancetype)initWithName:(NSString *)name
{
  return [self initWithName:name reporters:@[]];
}

- (instancetype)initWithName:(NSString *)name
                   reporters:(NSArray *)reporters
{
  self = [super initWithReporters:reporters];
  if (self) {
    _testName = [name copy];
    _tests = [[NSMutableArray alloc] init];
  }
  return self;
}


- (void)beginTestSuite:(NSDictionary *)event
{
  NSAssert(!_isStarted, @"Test should not have started yet.");
  _isStarted = true;
  _beginTestSuiteInfo = [event copy];

  [self publishWithEvent:event];
}

- (void)endTestSuite:(NSDictionary *)event
{
  NSAssert(_isStarted, @"Test must have already started.");
  _isFinished = true;

  _totalDuration = [event[kReporter_TimestampKey] doubleValue] - [_beginTestSuiteInfo[kReporter_TimestampKey] doubleValue];

  [_tests makeObjectsPerformSelector:@selector(publishEvents)];

  NSMutableDictionary *finalEvent = [event mutableCopy];
  finalEvent[kReporter_EndTestSuite_TestCaseCountKey] = @([self testCount]);
  finalEvent[kReporter_EndTestSuite_TotalFailureCountKey] = @([self totalFailures]);
  finalEvent[kReporter_EndTestSuite_UnexpectedExceptionCountKey] = @([self totalErrors]);
  finalEvent[kReporter_EndTestSuite_TestDurationKey] = @([self testDuration]);
  finalEvent[kReporter_EndTestSuite_TotalDurationKey] = @([self totalDuration]);
  [self publishWithEvent:finalEvent];
}

- (void)publishEventsForFinishedTests
{
  if (!_isStarted) {
    NSDictionary *event =
      EventDictionaryWithNameAndContent(kReporter_Events_BeginTestSuite,
        @{kReporter_BeginTestSuite_SuiteKey:_testName});
    [self beginTestSuite:event];
  }

  [[self finishedTests] makeObjectsPerformSelector:@selector(publishEvents)];

  if (!_isFinished && [[self unstartedTests] count] == 0) {
    NSDictionary *event =
      EventDictionaryWithNameAndContent(kReporter_Events_EndTestSuite, @{
        kReporter_EndTestSuite_SuiteKey:_testName,
        kReporter_EndTestSuite_TestCaseCountKey:@([self testCount]),
        kReporter_EndTestSuite_TotalFailureCountKey:@([self totalFailures]),
        kReporter_EndTestSuite_UnexpectedExceptionCountKey:@([self totalErrors]),
        kReporter_EndTestSuite_TotalDurationKey:@([self totalDuration]),
        kReporter_EndTestSuite_TestDurationKey:@([self testDuration]),
      });
    [self endTestSuite:event];
  }
}

- (void)publishEvents
{
  if (!_isStarted) {
    NSDictionary *event =
      EventDictionaryWithNameAndContent(kReporter_Events_BeginTestSuite,
        @{kReporter_BeginTestSuite_SuiteKey:_testName});
    [self beginTestSuite:event];
  }

  [_tests makeObjectsPerformSelector:@selector(publishEvents)];

  if (!_isFinished) {
    NSDictionary *event =
      EventDictionaryWithNameAndContent(kReporter_Events_EndTestSuite, @{
        kReporter_EndTestSuite_SuiteKey:_testName,
        kReporter_EndTestSuite_TestCaseCountKey:@([self testCount]),
        kReporter_EndTestSuite_TotalFailureCountKey:@([self totalFailures]),
        kReporter_EndTestSuite_UnexpectedExceptionCountKey:@([self totalErrors]),
        kReporter_EndTestSuite_TotalDurationKey:@([self totalDuration]),
        kReporter_EndTestSuite_TestDurationKey:@([self testDuration]),
    });
    [self endTestSuite:event];
  }
}

- (void)setReporters:(NSArray *)reporters
{
  super.reporters = reporters;
  [_tests makeObjectsPerformSelector:@selector(setReporters:) withObject:reporters];
}

#pragma mark - Test Manipulation Methods

- (void)insertTest:(OCTestEventState *)test atIndex:(NSUInteger)index
{
  test.reporters = self.reporters;
  [_tests insertObject:test atIndex:index];
}

- (void)addTest:(OCTestEventState *)test
{
  test.reporters = self.reporters;
  [_tests addObject:test];
}

- (void)addTestsFromArray:(NSArray *)tests
{
  [tests enumerateObjectsUsingBlock:^(NSString *testDesc, NSUInteger idx, BOOL *stop) {
    OCTestEventState *state = [[OCTestEventState alloc] initWithInputName:testDesc];
    [self addTest:state];
  }];
}

#pragma mark - Query Test Methods

- (OCTestEventState *)runningTest
{
  NSUInteger idx = [_tests indexOfObjectPassingTest:^(OCTestEventState *test, NSUInteger idx, BOOL *stop) {
    return [test isRunning];
  }];

  if (idx == NSNotFound) {
    return nil;
  } else {
    return _tests[idx];
  }
}

- (NSArray *)unstartedTests
{
  return [_tests filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL (OCTestEventState *test, NSDictionary *bindings) {
    return ![test isStarted];
  }]];
}

- (NSArray *)finishedTests
{
  return [_tests filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL (OCTestEventState *test, NSDictionary *bindings) {
    return [test isFinished];
  }]];
}

- (NSArray *)unfinishedTests
{
  return [_tests filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL (OCTestEventState *test, NSDictionary *bindings) {
    return ![test isFinished];
  }]];
}

- (OCTestEventState *)getTestWithTestName:(NSString *)name
{
  NSUInteger idx = [_tests indexOfObjectPassingTest:^(OCTestEventState *test, NSUInteger idx, BOOL *stop) {
    return [[test testName] isEqualToString:name];
  }];

  if (idx == NSNotFound) {
    return nil;
  } else {
    return _tests[idx];
  }
}

#pragma mark - Counter Methods

- (double)testDuration
{
  double __block total = 0.0;

  [_tests enumerateObjectsUsingBlock:^(OCTestEventState *state, NSUInteger idx, BOOL *stop) {
     total += state.duration;
   }];

  return total;
}

- (double)totalDuration
{
  return _totalDuration;
}

- (unsigned int)testCount
{
  return (unsigned int)[_tests count];
}

- (unsigned int)totalFailures
{
  NSArray *failedTests = [_tests filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL (OCTestEventState *test, NSDictionary *bindings) {
    return [test.result isEqualToString:@"failure"];
  }]];

  return (unsigned int)[failedTests count];
}

- (unsigned int)totalErrors
{
  NSArray *erroredTests = [_tests filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL (OCTestEventState *test, NSDictionary *bindings) {
    return [test.result isEqualToString:@"error"];
  }]];

  return (unsigned int)[erroredTests count];
}

@end
