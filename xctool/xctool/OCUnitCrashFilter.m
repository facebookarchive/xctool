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

#import "OCUnitCrashFilter.h"

#import <QuartzCore/QuartzCore.h>

#import "Reporter.h"

@implementation OCUnitCrashFilter

- (id)init
{
  if (self = [super init])
  {
    self.currentTestSuiteEventStack = [NSMutableArray array];
    self.currentTestSuiteEventTimestampStack = [NSMutableArray array];
    self.currentTestSuiteEventTestCountStack = [NSMutableArray array];
  }
  return self;
}

- (void)dealloc
{
  self.currentTestEvent = nil;
  self.currentTestSuiteEventStack = nil;
  self.currentTestSuiteEventTestCountStack = nil;
  self.currentTestSuiteEventTimestampStack = nil;
  self.currentTestOutput = nil;
  self.lastTestEvent = nil;
  [super dealloc];
}

- (void)handleEvent:(NSDictionary *)event
{
  NSString *eventName = event[@"event"];

  if ([eventName isEqualToString:kReporter_Events_BeginTest]) {
    NSAssert(self.currentTestEvent == nil, @"Got 'begin-test' before receiving the 'end-test' event from the last test.");
    self.currentTestEvent = event;
    self.currentTestEventTimestamp = CACurrentMediaTime();
    self.currentTestOutput = [NSMutableString string];

    for (NSMutableDictionary *testSuiteEvent in [self.currentTestSuiteEventTestCountStack reverseObjectEnumerator]) {
      testSuiteEvent[kReporter_EndTestSuite_TestCaseCountKey] = @([testSuiteEvent[kReporter_EndTestSuite_TestCaseCountKey] intValue] + 1);
    }
  } else if ([eventName isEqualToString:kReporter_Events_EndTest]) {
    NSAssert(self.currentTestEvent != nil, @"Got 'end-test' event before getting the 'begin-test' event.");
    self.lastTestEvent = self.currentTestEvent;
    self.currentTestEvent = nil;
    self.currentTestEventTimestamp = 0;
    self.currentTestOutput = nil;

    BOOL succeeded = [event[kReporter_EndTest_SucceededKey] boolValue];
    if (!succeeded) {
      for (NSMutableDictionary *testSuiteEvent in [self.currentTestSuiteEventTestCountStack reverseObjectEnumerator]) {
        testSuiteEvent[kReporter_EndTestSuite_TotalFailureCountKey] = @([testSuiteEvent[kReporter_EndTestSuite_TotalFailureCountKey] intValue] + 1);
      }
    }
  } else if ([eventName isEqualToString:kReporter_Events_BeginTestSuite]) {
    [self.currentTestSuiteEventStack addObject:event];

    // Keep track of when the suite started, so that we can generate a complete
    // 'end-test-suite' event later (if tests crash).
    [self.currentTestSuiteEventTimestampStack addObject:@(CACurrentMediaTime())];

    // Keep track of test counts so we can generate a complete 'end-test-suite'
    // event later (if tests crash).
    [self.currentTestSuiteEventTestCountStack addObject:
     [NSMutableDictionary dictionaryWithDictionary:@{
      kReporter_EndTestSuite_TotalFailureCountKey : @0,
      kReporter_EndTestSuite_TestCaseCountKey : @0,
      }]];
  } else if ([eventName isEqualToString:kReporter_Events_EndTestSuite]) {
    [self.currentTestSuiteEventStack removeLastObject];
    [self.currentTestSuiteEventTimestampStack removeLastObject];
    [self.currentTestSuiteEventTestCountStack removeLastObject];
  } else if ([eventName isEqualToString:kReporter_Events_TestOuput]) {
    NSAssert(_currentTestEvent != nil,
             @"'test-output' event should only come during a test: %@",
             event);
    [self.currentTestOutput appendString:event[kReporter_TestOutput_OutputKey]];
  }
}

- (void)fireEventsToSimulateTestRunFinishing:(NSArray *)reporters
                             fullProductName:(NSString *)fullProductName
                    concatenatedCrashReports:(NSString *)concatenatedCrashReports
{
  if (self.currentTestEvent != nil) {
    // It looks like we've crashed in the middle of running a test.  Record this test as a failure
    // in the test suite counts.
    for (NSMutableDictionary *testSuiteEvent in [self.currentTestSuiteEventTestCountStack reverseObjectEnumerator]) {
      testSuiteEvent[kReporter_EndTestSuite_TotalFailureCountKey] = @([testSuiteEvent[kReporter_EndTestSuite_TotalFailureCountKey] intValue] + 1);
    }

    // Fire another 'test-output' event - we'll include the crash report as if it
    // was written to stdout in the test.
    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:@{
     @"event" : kReporter_Events_TestOuput,
     kReporter_TestOutput_OutputKey : concatenatedCrashReports,
     }];

    // Fire a fake 'end-test' event.
    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:@{
     @"event" : kReporter_Events_EndTest,
     kReporter_EndTest_TestKey : self.currentTestEvent[kReporter_EndTest_TestKey],
     kReporter_EndTest_ClassNameKey : self.currentTestEvent[kReporter_EndTest_ClassNameKey],
     kReporter_EndTest_MethodNameKey : self.currentTestEvent[kReporter_EndTest_MethodNameKey],
     kReporter_EndTest_SucceededKey : @NO,
     kReporter_EndTest_TotalDurationKey : @(CACurrentMediaTime() - self.currentTestEventTimestamp),
     kReporter_EndTest_OutputKey : [self.currentTestOutput stringByAppendingString:concatenatedCrashReports],
     }];
  } else if (self.currentTestSuiteEventStack.count > 0) {
    // We've crashed outside of a running test.  Usually this means the previously run test
    // over-released something and OCUnit got an EXC_BAD_ACCESS while trying to drain the
    // NSAutoreleasePool.  It could be anything, though (e.g. some background thread).

    // To surface this to the Reporter, we create a fictional test.
    NSString *testName = [NSString stringWithFormat:@"%@_CRASHED", fullProductName];
    NSString *className = fullProductName;
    NSString *methodName = @"CRASHED";

    NSString *output =
      [NSString stringWithFormat:
       @"The tests crashed immediately after running '%@'.  Even though that test finished, it's "
       @"likely responsible for the crash.\n"
       @"\n"
       @"Tip: Consider re-running this test in Xcode with NSZombieEnabled=YES.  A common cause for "
       @"these kinds of crashes is over-released objects.  OCUnit creates a NSAutoreleasePool "
       @"before starting your test and drains it at the end of your test.  If an object has been "
       @"over-released, it'll trigger an EXC_BAD_ACCESS crash when draining the pool.\n"
       @"\n"
       @"%@",
       self.lastTestEvent[kReporter_EndTest_TestKey],
       concatenatedCrashReports];
    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:@{
     @"event" : kReporter_Events_BeginTest,
     kReporter_BeginTest_TestKey : testName,
     kReporter_BeginTest_ClassNameKey : className,
     kReporter_BeginTest_MethodNameKey : methodName,
     }];
    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:@{
     @"event" : kReporter_Events_TestOuput,
     kReporter_TestOutput_OutputKey : output,
     }];
    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:@{
     @"event" : kReporter_Events_EndTest,
     kReporter_EndTest_TestKey : testName,
     kReporter_EndTest_ClassNameKey : className,
     kReporter_EndTest_MethodNameKey : methodName,
     kReporter_EndTest_SucceededKey : @NO,
     kReporter_EndTest_TotalDurationKey : @(0),
     kReporter_EndTest_OutputKey : output,
     }];

    for (NSMutableDictionary *testSuiteEvent in [self.currentTestSuiteEventTestCountStack reverseObjectEnumerator]) {
      testSuiteEvent[kReporter_EndTestSuite_TestCaseCountKey] =
        @([testSuiteEvent[kReporter_EndTestSuite_TestCaseCountKey] intValue] + 1);
      testSuiteEvent[kReporter_EndTestSuite_TotalFailureCountKey] =
        @([testSuiteEvent[kReporter_EndTestSuite_TotalFailureCountKey] intValue] + 1);
    }
  }

  // For off any 'end-test-suite' events to keep the reporter sane (it expects every
  // suite to finish).
  for (int i = (int)[self.currentTestSuiteEventTimestampStack count] - 1; i >= 0; i--) {
    NSDictionary *testSuite = self.currentTestSuiteEventStack[i];
    CFTimeInterval testSuiteTimestamp = [self.currentTestSuiteEventTimestampStack[i] doubleValue];
    NSDictionary *testSuiteCounts = self.currentTestSuiteEventTestCountStack[i];

    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:@{
     @"event" : kReporter_Events_EndTestSuite,
     kReporter_EndTestSuite_SuiteKey : testSuite[kReporter_EndTestSuite_SuiteKey],
     kReporter_EndTestSuite_TotalDurationKey : @(CACurrentMediaTime() - testSuiteTimestamp),
     kReporter_EndTestSuite_TestCaseCountKey : testSuiteCounts[kReporter_EndTestSuite_TestCaseCountKey],
     kReporter_EndTestSuite_TotalFailureCountKey : testSuiteCounts[kReporter_EndTestSuite_TotalFailureCountKey],
     }];
  }
}

- (BOOL)testRunWasUnfinished
{
  return (self.currentTestEvent != nil || self.currentTestSuiteEventStack.count > 0);
}

@end
