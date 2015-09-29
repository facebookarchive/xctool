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

#import "EventBuffer.h"
#import "EventGenerator.h"
#import "EventSink.h"
#import "OCTestEventState.h"
#import "ReporterEvents.h"
#import "TestUtil.h"

@interface OCTestEventStateTests : XCTestCase
@end

@implementation OCTestEventStateTests

- (void)testInitWithInputName
{
  OCTestEventState *state =
    [[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"
                                       reporters:@[]];

  assertThat([state testName], equalTo(@"-[ATestClass aTestMethod]"));
}

- (void)testInitWithInvalidInputName
{
  XCTAssertThrowsSpecific([[OCTestEventState alloc] initWithInputName:@"ATestClassaTestMethod"
                                                            reporters: @[]],
                         NSException, @"Invalid class name should have raised exception");
}

- (void)testPublishFromStarted
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  OCTestEventState *state = [[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"
                                                               reporters:@[eventBuffer]];

  assertThatBool(state.isStarted, isFalse());
  assertThatBool(state.isFinished, isFalse());

  [state stateBeginTest];

  assertThatBool(state.isStarted, isTrue());
  assertThatBool(state.isFinished, isFalse());

  [state publishEvents];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(1));
  assertThat(events[0][@"event"], is(kReporter_Events_EndTest));
  assertThat(events[0][kReporter_EndTest_SucceededKey], is(@NO));
  assertThat(events[0][kReporter_EndTest_ResultKey], is(@"error"));

  assertThatBool(state.isStarted, isTrue());
  assertThatBool(state.isFinished, isTrue());
}

- (void)testPublishFromNotStarted
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  OCTestEventState *state =
  [[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"
                                     reporters:@[eventBuffer]];

  assertThatBool(state.isStarted, isFalse());
  assertThatBool(state.isFinished, isFalse());

  [state publishEvents];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(3));

  assertThat(events[0][@"event"], is(kReporter_Events_BeginTest));
  assertThat(events[0][kReporter_EndTest_TestKey], is(@"-[ATestClass aTestMethod]"));
  assertThat(events[0][kReporter_EndTest_ClassNameKey], is(@"ATestClass"));
  assertThat(events[0][kReporter_EndTest_MethodNameKey], is(@"aTestMethod"));

  assertThat(events[1][@"event"], is(kReporter_Events_TestOuput));
  assertThat(events[1][kReporter_TestOutput_OutputKey], is(@"Test did not run."));

  assertThat(events[2][@"event"], is(kReporter_Events_EndTest));
  assertThat(events[2][kReporter_EndTest_SucceededKey], is(@NO));
  assertThat(events[2][kReporter_EndTest_ResultKey], is(@"error"));

  assertThatBool(state.isStarted, isTrue());
  assertThatBool(state.isFinished, isTrue());
}

- (void)testStates
{
  OCTestEventState *state =
  [[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"];

  assertThatBool(state.isStarted, isFalse());
  assertThatBool(state.isFinished, isFalse());
  assertThatBool(state.isSuccessful, isFalse());
  assertThatBool([state isRunning], isFalse());
  assertThat(state.result, is(@"error"));

  [state stateBeginTest];

  assertThatBool(state.isStarted, isTrue());
  assertThatBool(state.isFinished, isFalse());
  assertThatBool(state.isSuccessful, isFalse());
  assertThatBool([state isRunning], isTrue());

  [state stateEndTest:YES result: @"success"];

  assertThatBool(state.isStarted, isTrue());
  assertThatBool(state.isFinished, isTrue());
  assertThatBool(state.isSuccessful, isTrue());
  assertThatBool([state isRunning], isFalse());
  assertThat(state.result, is(@"success"));

  state =
    [[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"];
  [state stateBeginTest];
  [state stateEndTest:NO result: @"failure"];

  assertThatBool(state.isStarted, isTrue());
  assertThatBool(state.isFinished, isTrue());
  assertThatBool(state.isSuccessful, isFalse());
  assertThatBool([state isRunning], isFalse());
  assertThat(state.result, is(@"failure"));
}

- (void)testOutput
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  OCTestEventState *state =
  [[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod" reporters:@[eventBuffer]];

  [state stateBeginTest];
  [state stateTestOutput:@"some output\n"];
  [state stateTestOutput:@"more output\n"];

  [state publishEvents];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(1));
  assertThat(events[0][@"event"], is(kReporter_Events_EndTest));
  assertThat(events[0][kReporter_EndTest_OutputKey], is(@"some output\nmore output\n"));
}

- (void)testPublishOutput
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  OCTestEventState *state =
  [[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod" reporters:@[eventBuffer]];

  [state stateBeginTest];
  [state stateTestOutput:@"some output\n"];
  [state stateTestOutput:@"more output\n"];
  [state appendOutput:@"output from us\n"];

  [state publishOutput];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(1));
  assertThat(events[0][@"event"], is(kReporter_Events_TestOuput));
  assertThat(events[0][kReporter_TestOutput_OutputKey], is(@"output from us\n"));
}

- (void)testAppendOutput
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  OCTestEventState *state =
  [[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod" reporters:@[eventBuffer]];

  [state stateBeginTest];
  [state stateTestOutput:@"some output\n"];
  [state stateTestOutput:@"more output\n"];
  [state appendOutput:@"output from us\n"];

  [state publishEvents];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(2));
  assertThat(events[0][@"event"], is(kReporter_Events_TestOuput));
  assertThat(events[0][kReporter_TestOutput_OutputKey], is(@"output from us\n"));
  assertThat(events[1][@"event"], is(kReporter_Events_EndTest));
  assertThat(events[1][kReporter_EndTest_OutputKey], is(@"some output\nmore output\noutput from us\n"));
}

- (void)testDuration
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  OCTestEventState *state =
  [[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod" reporters:@[eventBuffer]];

  [state stateBeginTest];

  [state publishEvents];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(1));
  assertThatDouble(state.duration, greaterThan(@0.0));
  assertThat(events[0][kReporter_EndTest_TotalDurationKey], closeTo(state.duration, 0.005f));
}

- (void)testEndWithDuration
{
  OCTestEventState *state =
    [[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"];

  [state stateBeginTest];
  [state stateEndTest:YES result:@"success" duration:123.4];

  assertThatDouble(state.duration, closeTo(123.4, 0.005f));
}

@end
