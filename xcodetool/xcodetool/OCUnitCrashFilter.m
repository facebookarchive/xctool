// Copyright 2004-present Facebook. All Rights Reserved.


#import "OCUnitCrashFilter.h"

#import <QuartzCore/QuartzCore.h>

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

  if ([eventName isEqualToString:@"begin-test"]) {
    NSAssert(self.currentTestEvent == nil, @"Got 'begin-test' before receiving the 'end-test' event from the last test.");
    self.currentTestEvent = event;
    self.currentTestEventTimestamp = CACurrentMediaTime();
    self.currentTestOutput = [NSMutableString string];

    for (NSMutableDictionary *testSuiteEvent in [self.currentTestSuiteEventTestCountStack reverseObjectEnumerator]) {
      testSuiteEvent[@"testCaseCount"] = @([testSuiteEvent[@"testCaseCount"] intValue] + 1);
    }
  } else if ([eventName isEqualToString:@"end-test"]) {
    NSAssert(self.currentTestEvent != nil, @"Got 'end-test' event before getting the 'begin-test' event.");
    self.lastTestEvent = self.currentTestEvent;
    self.currentTestEvent = nil;
    self.currentTestEventTimestamp = 0;
    self.currentTestOutput = nil;

    BOOL succeeded = [event[@"succeeded"] boolValue];
    if (!succeeded) {
      for (NSMutableDictionary *testSuiteEvent in [self.currentTestSuiteEventTestCountStack reverseObjectEnumerator]) {
        testSuiteEvent[@"totalFailureCount"] = @([testSuiteEvent[@"totalFailureCount"] intValue] + 1);
      }
    }
  } else if ([eventName isEqualToString:@"begin-test-suite"]) {
    [self.currentTestSuiteEventStack addObject:event];

    // Keep track of when the suite started, so that we can generate a complete
    // 'end-test-suite' event later (if tests crash).
    [self.currentTestSuiteEventTimestampStack addObject:@(CACurrentMediaTime())];

    // Keep track of test counts so we can generate a complete 'end-test-suite'
    // event later (if tests crash).
    [self.currentTestSuiteEventTestCountStack addObject:
     [NSMutableDictionary dictionaryWithDictionary:@{
      @"totalFailureCount" : @0,
      @"testCaseCount" : @0,
      }]];
  } else if ([eventName isEqualToString:@"end-test-suite"]) {
    [self.currentTestSuiteEventStack removeLastObject];
    [self.currentTestSuiteEventTimestampStack removeLastObject];
    [self.currentTestSuiteEventTestCountStack removeLastObject];
  } else if ([eventName isEqualToString:@"test-output"]) {
    NSAssert(self.currentTestEvent != nil, @"'test-output' event should only come during a test.");
    [self.currentTestOutput appendString:event[@"output"]];
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
      testSuiteEvent[@"totalFailureCount"] = @([testSuiteEvent[@"totalFailureCount"] intValue] + 1);
    }

    // Fire another 'test-output' event - we'll include the crash report as if it
    // was written to stdout in the test.
    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:@{
     @"event" : @"test-output",
     @"output" : concatenatedCrashReports,
     }];
    
    // Fire a fake 'end-test' event.
    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:@{
     @"event" : @"end-test",
     @"test" : self.currentTestEvent[@"test"],
     @"succeeded" : @NO,
     @"totalDuration" : @(CACurrentMediaTime() - self.currentTestEventTimestamp),
     @"output" : [self.currentTestOutput stringByAppendingString:concatenatedCrashReports],
     }];
  } else if (self.currentTestSuiteEventStack.count > 0) {
    // We've crashed outside of a running test.  Usually this means the previously run test
    // over-released something and OCUnit got an EXC_BAD_ACCESS while trying to drain the
    // NSAutoreleasePool.  It could be anything, though (e.g. some background thread).

    // To surface this to the Reporter, we create a fictional test.
    NSString *testName = [NSString stringWithFormat:@"%@_CRASHED", fullProductName];
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
       self.lastTestEvent[@"test"],
       concatenatedCrashReports];
    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:@{
     @"event" : @"begin-test",
     @"test" : testName,
     }];
    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:@{
     @"event" : @"test-output",
     @"output" : output,
     }];
    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:@{
     @"event" : @"end-test",
     @"test" : testName,
     @"succeeded" : @NO,
     @"totalDuration" : @(0),
     @"output" : output,
     }];
    
    for (NSMutableDictionary *testSuiteEvent in [self.currentTestSuiteEventTestCountStack reverseObjectEnumerator]) {
      testSuiteEvent[@"testCaseCount"] = @([testSuiteEvent[@"testCaseCount"] intValue] + 1);
      testSuiteEvent[@"totalFailureCount"] = @([testSuiteEvent[@"totalFailureCount"] intValue] + 1);
    }
  }

  // For off any 'end-test-suite' events to keep the reporter sane (it expects every
  // suite to finish).
  for (int i = (int)[self.currentTestSuiteEventTimestampStack count] - 1; i >= 0; i--) {
    NSDictionary *testSuite = self.currentTestSuiteEventStack[i];
    CFTimeInterval testSuiteTimestamp = [self.currentTestSuiteEventTimestampStack[i] doubleValue];
    NSDictionary *testSuiteCounts = self.currentTestSuiteEventTestCountStack[i];

    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:@{
     @"event" : @"end-test-suite",
     @"suite" : testSuite[@"suite"],
     @"totalDuration" : @(CACurrentMediaTime() - testSuiteTimestamp),
     @"testCaseCount" : testSuiteCounts[@"testCaseCount"],
     @"totalFailureCount" : testSuiteCounts[@"totalFailureCount"],
     }];
  }
}

- (BOOL)testRunWasUnfinished
{
  return (self.currentTestEvent != nil || self.currentTestSuiteEventStack.count > 0);
}

@end
