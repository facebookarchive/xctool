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

#import <XCTest/XCTest.h>

#import "EventSink.h"
#import "EventBuffer.h"
#import "TestRunState.h"
#import "ReporterEvents.h"
#import "TestUtil.h"

static NSArray *EventsForFakeRun()
{
  return @[
    @{@"event" : @"begin-test-suite", @"suite" : kReporter_TestSuite_TopLevelSuiteName},
    @{@"event" : @"begin-test", @"test" : @"-[OtherTests testSomething]"},
    @{@"event" : @"simulator-output", @"output" : @"puppies!\n", @"timestamp": @"1447051934.118537"},
    @{@"event" : @"end-test", @"test" : @"-[OtherTests testSomething]", @"succeeded" : @NO, @"output" : @"puppies!\n", @"totalDuration" : @1.0},
    @{@"event" : @"begin-test", @"test" : @"-[OtherTests testAnother]"},
    @{@"event" : @"end-test", @"test" : @"-[OtherTests testAnother]", @"succeeded" : @YES, @"output" : @"", @"totalDuration" : @1.0},
    @{@"event" : @"end-test-suite", @"suite" : @"OtherTests", @"testCaseCount" : @2, @"totalFailureCount" : @1, @"totalDuration" : @1.0, @"testDuration" : @1.0, @"unexpectedExceptionCount" : @1},
    ];
}

static TestRunState *TestRunStateForFakeRun(id<EventSink> sink)
{
  return [[TestRunState alloc] initWithTests:@[@"OtherTests/testSomething", @"OtherTests/testAnother"]
                                    reporters:@[sink]];
}

@interface TestRunStateTests : XCTestCase {
}
@end

@implementation TestRunStateTests

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

  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  TestRunState *state =
    [[TestRunState alloc] initWithTests:testList
                                    reporters:@[eventBuffer]];
  [state prepareToRun];
  [self sendEventsFromFile:TEST_DATA @"JSONStreamReporter-runtests-for-test-state-tests.txt"
                toReporter:state];
  [state didFinishRunWithStartupError:nil otherErrors:nil];

  assertThat(eventBuffer.events, hasCountOf(88));
  assertThat(SelectEventFields(eventBuffer.events, kReporter_Events_BeginTest, @"event"), hasCountOf(7));
  assertThat(SelectEventFields(eventBuffer.events, kReporter_Events_EndTest, @"event"), hasCountOf(7));
}

- (void)testCrashBeforeTestsRan
{
  void (^testCrashBeforeTestsRan)(NSArray *, NSArray *expectedEvents) =
  ^(NSArray *events, NSArray *expectedEvents){
    EventBuffer *eventBuffer = [[EventBuffer alloc] init];
    TestRunState *state = TestRunStateForFakeRun(eventBuffer);

    [state prepareToRun];
    [self sendEvents:events toReporter:state];
    [state didFinishRunWithStartupError:nil otherErrors:nil];

    assertThat(SelectEventFields(eventBuffer.events, nil, @"event"),
               equalTo(expectedEvents));

    // A "fake" test gets inserted at the top to indicate the bundle crashed.
    assertThat(SelectEventFields(eventBuffer.events, kReporter_Events_EndTest, kReporter_EndTest_TestKey),
               equalTo(@[@"-[FAILED_BEFORE TESTS_RAN]",
                         @"-[OtherTests testSomething]",
                         @"-[OtherTests testAnother]"]));

    NSArray *output = SelectEventFields(eventBuffer.events, kReporter_Events_TestOuput, kReporter_TestOutput_OutputKey);
    assertThat(output[0], equalTo(@"Test did not run: the test bundle stopped running or crashed before the test suite started.\n"
                                  @"\n"
                                  @"Some output that happens before tests run."));
    assertThat(output[1], equalTo(@"Test did not run: the test bundle stopped running or crashed before the test suite started."));
    assertThat(output[2], equalTo(@"Test did not run: the test bundle stopped running or crashed before the test suite started."));
  };

  NSDictionary *outputBeforeTests = @{@"event" : kReporter_Events_OutputBeforeTestBundleStarts,
                                      kReporter_OutputBeforeTestBundleStarts_OutputKey : @"Some output that happens before tests run."};

  // Send no events, except the output before the tests.
  testCrashBeforeTestsRan(@[outputBeforeTests],
                          @[kReporter_Events_BeginTestSuite,
                            kReporter_Events_BeginTest,
                            kReporter_Events_TestOuput,
                            kReporter_Events_EndTest,
                            kReporter_Events_BeginTest,
                            kReporter_Events_TestOuput,
                            kReporter_Events_EndTest,
                            kReporter_Events_BeginTest,
                            kReporter_Events_TestOuput,
                            kReporter_Events_EndTest,
                            kReporter_Events_EndTestSuite]);

  // Send the 'begin-test-suite' event, but stop before the first test.
  testCrashBeforeTestsRan([@[outputBeforeTests] arrayByAddingObjectsFromArray:
                           [EventsForFakeRun() subarrayWithRange:NSMakeRange(0, 1)]],
                          @[kReporter_Events_BeginTestSuite,
                            kReporter_Events_BeginTest,
                            kReporter_Events_TestOuput,
                            kReporter_Events_EndTest,
                            kReporter_Events_BeginTest,
                            kReporter_Events_TestOuput,
                            kReporter_Events_EndTest,
                            kReporter_Events_BeginTest,
                            kReporter_Events_TestOuput,
                            kReporter_Events_EndTest,
                            kReporter_Events_EndTestSuite]);
}

- (void)testCrashedAfterFirstTestStarts
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  TestRunState *state = TestRunStateForFakeRun(eventBuffer);

  [state prepareToRun];
  [self sendEvents:[EventsForFakeRun() subarrayWithRange:NSMakeRange(0, 2)]
          toReporter:state];
  [state didFinishRunWithStartupError:nil otherErrors:nil];

  assertThat(SelectEventFields(eventBuffer.events, nil, @"event"),
             equalTo(@[kReporter_Events_BeginTestSuite,
                       kReporter_Events_BeginTest,
                       kReporter_Events_TestOuput,
                       kReporter_Events_EndTest]));

  assertThat(SelectEventFields(eventBuffer.events, kReporter_Events_EndTest, kReporter_EndTest_TestKey),
             equalTo(@[@"-[OtherTests testSomething]"]));

  NSArray *output = SelectEventFields(eventBuffer.events, kReporter_Events_TestOuput, kReporter_TestOutput_OutputKey);
  assertThat(output[0], equalTo(@"Test crashed while running."));
}

- (void)testCrashedAfterFirstTestFinishes
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  TestRunState *state = TestRunStateForFakeRun(eventBuffer);

  [state prepareToRun];
  [self sendEvents:[EventsForFakeRun() subarrayWithRange:NSMakeRange(0, 4)]
        toReporter:state];
  [state didFinishRunWithStartupError:nil otherErrors:nil];

  assertThat(SelectEventFields(eventBuffer.events, nil, @"event"),
             equalTo(@[kReporter_Events_BeginTestSuite,
                       kReporter_Events_BeginTest,
                       kReporter_Events_TestOuput,
                       kReporter_Events_EndTest,
                       kReporter_Events_BeginTest,
                       kReporter_Events_TestOuput,
                       kReporter_Events_EndTest,
                       kReporter_Events_BeginTest,
                       kReporter_Events_TestOuput,
                       kReporter_Events_EndTest,
                       kReporter_Events_EndTestSuite]));

  // A "fake" test gets inserted to advertise the failure.
  assertThat(SelectEventFields(eventBuffer.events, kReporter_Events_EndTest, kReporter_EndTest_TestKey),
             equalTo(@[@"-[OtherTests testSomething]",
                       @"-[OtherTests testSomething_MAYBE_CRASHED]",
                       @"-[OtherTests testAnother]"]));

  NSArray *output = SelectEventFields(eventBuffer.events, kReporter_Events_TestOuput, kReporter_TestOutput_OutputKey);
  assertThat(output[0],
             equalTo(@"puppies!\n"));
  assertThat(output[1],
             equalTo(@"The test bundle stopped running or crashed immediately after running '-[OtherTests testSomething]'.  "
                     @"Even though that test finished, it's likely responsible for the crash."));
}

- (void)testTestsNeverRanBecauseOfStartupError
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  TestRunState *state = TestRunStateForFakeRun(eventBuffer);

  [state prepareToRun];
  [self sendEvents:@[]
        toReporter:state];
  [state didFinishRunWithStartupError:@"cupcakes candy donuts cookies" otherErrors:nil];

  assertThat(SelectEventFields(eventBuffer.events, nil, @"event"),
             equalTo(@[kReporter_Events_BeginTestSuite,
                       kReporter_Events_BeginTest,
                       kReporter_Events_TestOuput,
                       kReporter_Events_EndTest,
                       kReporter_Events_BeginTest,
                       kReporter_Events_TestOuput,
                       kReporter_Events_EndTest,
                       kReporter_Events_BeginTest,
                       kReporter_Events_TestOuput,
                       kReporter_Events_EndTest,
                       kReporter_Events_EndTestSuite]));

  // A "fake" test gets inserted to advertise the failure.
  assertThat(SelectEventFields(eventBuffer.events, kReporter_Events_EndTest, kReporter_EndTest_TestKey),
             equalTo(@[@"-[TEST_BUNDLE FAILED_TO_START]",
                       @"-[OtherTests testSomething]",
                       @"-[OtherTests testAnother]",
                       ]));

  NSArray *output = SelectEventFields(eventBuffer.events, kReporter_Events_TestOuput, kReporter_TestOutput_OutputKey);
  assertThat(output[0], equalTo(@"There was a problem starting the test bundle: cupcakes candy donuts cookies"));
  assertThat(output[1], equalTo(@"Test did not run: cupcakes candy donuts cookies"));
  assertThat(output[1], equalTo(@"Test did not run: cupcakes candy donuts cookies"));
}

- (void)testCrashedAfterLastTestFinishes
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  TestRunState *state = TestRunStateForFakeRun(eventBuffer);

  [state prepareToRun];
  [self sendEvents:[EventsForFakeRun() subarrayWithRange:NSMakeRange(0, 6)]
        toReporter:state];
  [state didFinishRunWithStartupError:nil otherErrors:nil];

  // In this case there are no tests left with which to report the error, so we
  // create a fake one just so we have a place to advertise the error.
  assertThat(SelectEventFields(eventBuffer.events, nil, @"event"),
             equalTo(@[kReporter_Events_BeginTestSuite,
                       kReporter_Events_BeginTest,
                       kReporter_Events_TestOuput,
                       kReporter_Events_EndTest,
                       kReporter_Events_BeginTest,
                       kReporter_Events_EndTest,
                       kReporter_Events_BeginTest,
                       kReporter_Events_TestOuput,
                       kReporter_Events_EndTest,
                       kReporter_Events_EndTestSuite]));

  // A "fake" test gets inserted to advertise the failure.
  assertThat(SelectEventFields(eventBuffer.events, kReporter_Events_EndTest, kReporter_EndTest_TestKey),
             equalTo(@[@"-[OtherTests testSomething]",
                       @"-[OtherTests testAnother]",
                       @"-[OtherTests testAnother_MAYBE_CRASHED]"]));

  NSArray *output = SelectEventFields(eventBuffer.events, kReporter_Events_TestOuput, kReporter_TestOutput_OutputKey);
  assertThat(output[0],
             equalTo(@"puppies!\n"));
  assertThat(output[1],
             equalTo(@"The test bundle stopped running or crashed immediately after running '-[OtherTests testAnother]'.  "
                     @"Even though that test finished, it's likely responsible for the crash."));
}

- (void)testCrashedAfterTestSuiteFinishes
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  TestRunState *state = TestRunStateForFakeRun(eventBuffer);

  [state prepareToRun];
  [self sendEvents:EventsForFakeRun()
        toReporter:state];
  [state didFinishRunWithStartupError:nil otherErrors:nil];

  // Not much we can do here, make sure no events are shipped out
  assertThatInteger(eventBuffer.events.count, equalToInteger(7));
  assertThat(SelectEventFields(eventBuffer.events, kReporter_Events_BeginTest, @"event"), hasCountOf(2));
  assertThat(SelectEventFields(eventBuffer.events, kReporter_Events_EndTest, @"event"), hasCountOf(2));
}

@end
