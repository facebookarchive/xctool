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

#import "EventGenerator.h"
#import "OCTestSuiteEventState.h"
#import "ReporterEvents.h"

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

- (void)dealloc
{
  [_testName release];
  [_tests release];
  [super dealloc];
}

- (void)beginTestSuite
{
  NSAssert(!_isStarted, @"Test should not have started yet.");
  _isStarted = true;
}

- (void)endTestSuite
{
  NSAssert(_isStarted, @"Test must have already started.");
  _isFinished = true;
}

- (double)duration
{
  double __block total = 0.0;

  [_tests
   enumerateObjectsUsingBlock:^(OCTestEventState *state, NSUInteger idx, BOOL *stop) {
     total += state.duration;
   }];

  return total;
}

- (void)publishEvents
{
  if (!_isStarted) {
    [self publishWithEvent:
      EventDictionaryWithNameAndContent(kReporter_Events_BeginTestSuite,
        @{kReporter_BeginTestSuite_SuiteKey:self.testName})
    ];
    [self beginTestSuite];
  }

  [_tests makeObjectsPerformSelector:@selector(publishEvents)];

  if (!_isFinished) {
    [self publishWithEvent:
      EventDictionaryWithNameAndContent(kReporter_Events_EndTestSuite, @{
        kReporter_EndTestSuite_SuiteKey:self.testName,
        kReporter_EndTestSuite_TotalDurationKey:@(self.duration),
        kReporter_EndTestSuite_TestCaseCountKey:@(self.testCount),
        kReporter_EndTestSuite_TotalFailureCountKey:@(self.totalFailures)
    })];
    [self endTestSuite];
  }
}

- (void)setReporters:(NSArray *)reporters
{
  super.reporters = reporters;
  [_tests makeObjectsPerformSelector:@selector(setReporters:) withObject:reporters];
}

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
    [state release];
  }];
}

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

- (unsigned int)testCount
{
  return (unsigned int)[_tests count];
}

- (unsigned int)totalFailures
{
  NSArray *failedTests = [_tests filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL (OCTestEventState *test, NSDictionary *bindings) {
    return ![test isSuccessful];
  }]];

  return (unsigned int)[failedTests count];
}

@end
