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

#import <SenTestingKit/SenTestingKit.h>

#import "EventSink.h"
#import "EventBuffer.h"
#import "OCUnitCrashFilter.h"
#import "ReporterEvents.h"
#import "TestUtil.h"

static NSArray *EventsForFullRun()
{
  return @[
    @{@"event" : @"begin-test-suite", @"suite" : kReporter_TestSuite_TopLevelSuiteName},
    @{@"event" : @"begin-test", @"test" : @"-[OtherTests testSomething]"},
    @{@"event" : @"test-output", @"output" : @"puppies!\n"},
    @{@"event" : @"end-test", @"test" : @"-[OtherTests testSomething]", @"succeeded" : @NO, @"output" : @"puppies!\n", @"totalDuration" : @1.0},
    @{@"event" : @"begin-test", @"test" : @"-[OtherTests testAnother]"},
    @{@"event" : @"end-test", @"test" : @"-[OtherTests testAnother]", @"succeeded" : @YES, @"output" : @"", @"totalDuration" : @1.0},
    @{@"event" : @"end-test-suite", @"suite" : @"OtherTests", @"testCaseCount" : @2, @"totalFailureCount" : @1, @"totalDuration" : @1.0, @"testDuration" : @1.0, @"unexpectedExceptionCount" : @1},
    ];
}

static OCUnitCrashFilter *CrashFilterWithEventSink(id<EventSink> sink)
{
  OCUnitCrashFilter *crashFilter = [[[OCUnitCrashFilter alloc] initWithTests:@[@"OtherTests/testSomething", @"OtherTests/testAnother"]
                                                                   reporters:@[sink]] autorelease];
  crashFilter.crashReportCollectionTime = 0.25;
  return crashFilter;
}

@interface OCUnitCrashFilterTests : SenTestCase {
}
@end

@implementation OCUnitCrashFilterTests

- (void)assertEvents:(NSArray *)events containsEvents:(NSArray *)eventKeys
{
  NSAssert([events count] == [eventKeys count],
           @"Expected event keys '%@' but got events: %@", eventKeys, [events valueForKey:@"event"]);

  [eventKeys enumerateObjectsUsingBlock:^(NSString *eventKey, NSUInteger idx, BOOL *stop) {
    NSAssert([eventKey isEqualToString:events[idx][@"event"]],
             @"Expected event key '%@' but got event key '%@'", eventKey, events[idx][@"event"]);
  }];
}

- (void)sendEvents:(NSArray *)events toReporter:(Reporter *)reporter
{
  for (NSDictionary *event in events) {
    [reporter handleEvent:event];
  }
}

- (void)sendEventsFromFile:(NSString *)path toReporter:(Reporter *)reporter
{
  NSString *pathContents = [NSString stringWithContentsOfFile:path
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
  NSArray *lines = [pathContents componentsSeparatedByCharactersInSet:
                    [NSCharacterSet newlineCharacterSet]];
  for (NSString *line in lines) {
    if ([line length] == 0) {
      break;
    }

    NSError *error = nil;
    NSDictionary *event = [NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding]
                                                          options:0
                                                            error:&error];
    NSAssert(event != nil, @"Error decoding JSON '%@' with error: %@",
             line,
             [error localizedFailureReason]);
    NSAssert(event[@"event"], @"Event type not found: '%@'", line);
    [reporter handleEvent:event];
  }
}

- (void)testSuccessfulRun
{
  NSArray *testList = @[@"OtherTests/testSomething",
                        @"SomeTests/testBacktraceOutputIsCaptured",
                        @"SomeTests/testOutputMerging",
                        @"SomeTests/testPrintSDK",
                        @"SomeTests/testStream",
                        @"SomeTests/testWillFail",
                        @"SomeTests/testWillPass"];

  EventBuffer *eventBuffer = [[[EventBuffer alloc] init] autorelease];
  OCUnitCrashFilter *state =
    [[[OCUnitCrashFilter alloc] initWithTests:testList
                                    reporters:@[eventBuffer]] autorelease];
  [state prepareToRun];
  [self sendEventsFromFile:TEST_DATA @"JSONStreamReporter-runtests.txt"
                toReporter:state];
  [state finishedRun:NO error:nil];

  assertThat(eventBuffer.events, hasCountOf(0));
}

- (void)testCrashedBeforeTestSuiteStart
{
  EventBuffer *eventBuffer = [[[EventBuffer alloc] init] autorelease];
  OCUnitCrashFilter *state = CrashFilterWithEventSink(eventBuffer);

  [state prepareToRun];
  [self sendEvents:@[] toReporter:state];
  [state finishedRun:YES error:nil];

  [self assertEvents:eventBuffer.events containsEvents:
    @[kReporter_Events_BeginTestSuite,
      kReporter_Events_BeginTest,
      kReporter_Events_TestOuput,
      kReporter_Events_EndTest,
      kReporter_Events_BeginTest,
      kReporter_Events_TestOuput,
      kReporter_Events_EndTest,
      kReporter_Events_EndTestSuite]];

  assertThat(eventBuffer.events[2][@"output"], containsString(@"crashed before starting a test-suite"));
}

- (void)testCrashedAfterTestSuiteStartBeforeTests
{
  EventBuffer *eventBuffer = [[[EventBuffer alloc] init] autorelease];
  OCUnitCrashFilter *state = CrashFilterWithEventSink(eventBuffer);

  [state prepareToRun];
  [self sendEvents:[EventsForFullRun() subarrayWithRange:NSMakeRange(0, 1)]
        toReporter:state];
  [state finishedRun:YES error:nil];

  [self assertEvents:eventBuffer.events containsEvents:
   @[kReporter_Events_BeginTest,
     kReporter_Events_TestOuput,
     kReporter_Events_EndTest,
     kReporter_Events_BeginTest,
     kReporter_Events_TestOuput,
     kReporter_Events_EndTest,
     kReporter_Events_EndTestSuite]];

  assertThat(eventBuffer.events[1][@"output"],
             containsString(@"after starting a test-suite but before starting a test\n\n"));
}

- (void)testCrashedAfterFirstTestStarts
{
  EventBuffer *eventBuffer = [[[EventBuffer alloc] init] autorelease];
  OCUnitCrashFilter *state = CrashFilterWithEventSink(eventBuffer);

  [state prepareToRun];
  [self sendEvents:[EventsForFullRun() subarrayWithRange:NSMakeRange(0, 2)]
          toReporter:state];
  [state finishedRun:YES error:nil];

  [self assertEvents:eventBuffer.events containsEvents:
   @[kReporter_Events_TestOuput,
     kReporter_Events_EndTest,
     kReporter_Events_BeginTest,
     kReporter_Events_TestOuput,
     kReporter_Events_EndTest,
     kReporter_Events_EndTestSuite]];

  assertThat(eventBuffer.events[0][@"output"], containsString(@"crashed binary while running\n"));
}

- (void)testCrashedAfterFirstTestFinishes
{
  EventBuffer *eventBuffer = [[[EventBuffer alloc] init] autorelease];
  OCUnitCrashFilter *state = CrashFilterWithEventSink(eventBuffer);

  [state prepareToRun];
  [self sendEvents:[EventsForFullRun() subarrayWithRange:NSMakeRange(0, 4)]
        toReporter:state];
  [state finishedRun:YES error:nil];

  [self assertEvents:eventBuffer.events containsEvents:
   @[kReporter_Events_BeginTest,
     kReporter_Events_TestOuput,
     kReporter_Events_EndTest,
     kReporter_Events_EndTestSuite]];

  assertThat(eventBuffer.events[1][@"output"], containsString(@"crashed immediately after running"));
}

- (void)testErrorMessagePropogatesToTestOutput
{
  EventBuffer *eventBuffer = [[[EventBuffer alloc] init] autorelease];
  OCUnitCrashFilter *state = CrashFilterWithEventSink(eventBuffer);

  [state prepareToRun];
  [self sendEvents:[EventsForFullRun() subarrayWithRange:NSMakeRange(0, 4)]
        toReporter:state];
  [state finishedRun:YES error:@"cupcakes candy donuts cookies"];

  [self assertEvents:eventBuffer.events containsEvents:
   @[kReporter_Events_BeginTest,
     kReporter_Events_TestOuput,
     kReporter_Events_EndTest,
     kReporter_Events_EndTestSuite]];
  
  assertThat(eventBuffer.events[1][@"output"], containsString(@"cupcakes candy donuts cookies"));
}

- (void)testCrashedAfterLastTestFinishes
{
  EventBuffer *eventBuffer = [[[EventBuffer alloc] init] autorelease];
  OCUnitCrashFilter *state = CrashFilterWithEventSink(eventBuffer);

  [state prepareToRun];
  [self sendEvents:[EventsForFullRun() subarrayWithRange:NSMakeRange(0, 6)]
        toReporter:state];
  [state finishedRun:YES error:nil];

  // In this case there are no tests left with which to report the error, so we have to create a fake one
  [self assertEvents:eventBuffer.events containsEvents:
   @[kReporter_Events_BeginTest,
     kReporter_Events_TestOuput,
     kReporter_Events_EndTest,
     kReporter_Events_EndTestSuite]];

  assertThat(eventBuffer.events[0][@"test"], containsString(@"_MAYBE_CRASHED"));
  assertThat(eventBuffer.events[1][@"output"], containsString(@"crashed immediately after running"));
}

- (void)testCrashedAfterTestSuiteFinishes
{
  EventBuffer *eventBuffer = [[[EventBuffer alloc] init] autorelease];
  OCUnitCrashFilter *state = CrashFilterWithEventSink(eventBuffer);

  [state prepareToRun];
  [self sendEvents:EventsForFullRun()
        toReporter:state];
  [state finishedRun:YES  error:nil];

  // Not much we can do here, make sure no events are shipped out
  [self assertEvents:eventBuffer.events containsEvents:@[]];
}

- (void)testExtendedInfo
{
  EventBuffer *eventBuffer = [[[EventBuffer alloc] init] autorelease];
  OCUnitCrashFilter *state = CrashFilterWithEventSink(eventBuffer);

  [state prepareToRun];
  [self sendEvents:@[] toReporter:state];
  [state finishedRun:YES error:nil];

  [self assertEvents:eventBuffer.events containsEvents:
   @[kReporter_Events_BeginTestSuite,
     kReporter_Events_BeginTest,
     kReporter_Events_TestOuput,
     kReporter_Events_EndTest,
     kReporter_Events_BeginTest,
     kReporter_Events_TestOuput,
     kReporter_Events_EndTest,
     kReporter_Events_EndTestSuite]];

  // Normally the extended info has the crash report, but since we're just testing here we'll instead just look
  // for the double newline that comes before the crash report
  assertThat(eventBuffer.events[2][@"output"], containsString(@"crashed before starting a test-suite\n\n"));
  assertThat(eventBuffer.events[5][@"output"], endsWith(@"crashed before starting a test-suite\n"));
}

@end
