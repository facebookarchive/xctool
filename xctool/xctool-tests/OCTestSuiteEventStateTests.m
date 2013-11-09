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

#import "EventBuffer.h"
#import "EventGenerator.h"
#import "OCTestSuiteEventState.h"
#import "OCTestEventState.h"
#import "ReporterEvents.h"
#import "TestUtil.h"

@interface OCTestSuiteEventStateTests : SenTestCase

@end

@implementation OCTestSuiteEventStateTests

- (void)testInitWithEvent
{
  OCTestSuiteEventState *state =
    [[[OCTestSuiteEventState alloc] initWithName:@"ATestSuite"] autorelease];
  assertThat([state testName], is(@"ATestSuite"));
  assertThatInteger([[state tests] count], equalToInteger(0));
}

- (void)testInitWithName
{
  OCTestSuiteEventState *state =
    [[[OCTestSuiteEventState alloc] initWithName:@"ATestSuite"] autorelease];

  assertThat([state testName], is(@"ATestSuite"));
}

- (void)testPublishFromStarted
{
  EventBuffer *eventBuffer = [[[EventBuffer alloc] init] autorelease];
  OCTestSuiteEventState *state =
  [[[OCTestSuiteEventState alloc] initWithName:@"ATestSuite" reporters:@[eventBuffer]] autorelease];

  assertThatBool(state.isStarted, equalToBool(NO));
  assertThatBool(state.isFinished, equalToBool(NO));

  [state beginTestSuite];

  assertThatBool(state.isStarted, equalToBool(YES));
  assertThatBool(state.isFinished, equalToBool(NO));

  [state publishEvents];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(1));
  assertThat(events[0][@"event"], is(kReporter_Events_EndTestSuite));
  assertThat(events[0][kReporter_EndTestSuite_SuiteKey], is(@"ATestSuite"));
  assertThat(events[0][kReporter_EndTestSuite_TotalDurationKey], is(@(state.duration)));
  assertThat(events[0][kReporter_EndTestSuite_TestCaseCountKey], is(@0));
  assertThat(events[0][kReporter_EndTestSuite_TotalFailureCountKey], is(@0));

  assertThatBool(state.isStarted, equalToBool(YES));
  assertThatBool(state.isFinished, equalToBool(YES));
}

- (void)testPublishFromNotStarted
{
  EventBuffer *eventBuffer = [[[EventBuffer alloc] init] autorelease];
  OCTestSuiteEventState *state =
    [[[OCTestSuiteEventState alloc] initWithName:@"ATestSuite" reporters:@[eventBuffer]] autorelease];

  assertThatBool(state.isStarted, equalToBool(NO));
  assertThatBool(state.isFinished, equalToBool(NO));

  [state publishEvents];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(2));
  assertThat(events[0][@"event"], is(kReporter_Events_BeginTestSuite));
  assertThat(events[0][kReporter_BeginTestSuite_SuiteKey], is(@"ATestSuite"));
  assertThat(events[1][@"event"], is(kReporter_Events_EndTestSuite));
  assertThat(events[1][kReporter_EndTestSuite_SuiteKey], is(@"ATestSuite"));
  assertThat(events[1][kReporter_EndTestSuite_TotalDurationKey], is(@(state.duration)));
  assertThat(events[1][kReporter_EndTestSuite_TestCaseCountKey], is(@0));
  assertThat(events[1][kReporter_EndTestSuite_TotalFailureCountKey], is(@0));

  assertThatBool(state.isStarted, equalToBool(YES));
  assertThatBool(state.isFinished, equalToBool(YES));
}

- (void)testFromFinished
{
  EventBuffer *eventBuffer = [[[EventBuffer alloc] init] autorelease];
  OCTestSuiteEventState *state =
    [[[OCTestSuiteEventState alloc] initWithName:@"ATestSuite"] autorelease];

  assertThatBool(state.isStarted, equalToBool(NO));
  assertThatBool(state.isFinished, equalToBool(NO));

  [state beginTestSuite];
  [state endTestSuite];

  [state publishEvents];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(0));
}

- (void)testDuration
{
  OCTestSuiteEventState *state =
    [[[OCTestSuiteEventState alloc] initWithName:@"ATestSuite"] autorelease];
  OCTestEventState *testAState =
  [[[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"] autorelease];
  OCTestEventState *testBState =
  [[[OCTestEventState alloc] initWithInputName:@"ATestClass/bTestMethod"] autorelease];

  [state addTest:testAState];
  [state addTest:testBState];

  [state beginTestSuite];
  [testAState stateBeginTest];
  [testAState stateEndTest:YES result:@"success"];
  [testBState stateBeginTest];
  [testBState stateEndTest:NO result:@"failure"];
  testAState.duration = 5.0f;
  testBState.duration = 10.0f;
  [state endTestSuite];

  assertThatFloat(state.duration, closeTo(15.0, 0.1f));
}

- (void)testAddTests
{
  EventBuffer *eventBuffer = [[[EventBuffer alloc] init] autorelease];
  OCTestSuiteEventState *state =
    [[[OCTestSuiteEventState alloc] initWithName:@"ATestSuite" reporters:@[eventBuffer]] autorelease];

  OCTestEventState *testAState =
    [[[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"] autorelease];
  OCTestEventState *testBState =
    [[[OCTestEventState alloc] initWithInputName:@"ATestClass/bTestMethod"] autorelease];

  [state addTest:testAState];
  [state addTest:testBState];

  [state beginTestSuite];
  [testAState stateBeginTest];
  [testAState stateEndTest:YES result:@"success"];
  [testBState stateBeginTest];
  [testBState stateEndTest:NO result:@"failure"];

  assertThatInteger(state.testCount, equalToInteger(2));
  assertThatInteger(state.totalFailures, equalToInteger(1));

  [state publishEvents];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(1));
  assertThat(events[0][kReporter_EndTestSuite_TestCaseCountKey], equalToInt(2));
  assertThat(events[0][kReporter_EndTestSuite_TotalFailureCountKey], equalToInt(1));
  assertThat(events[0][kReporter_EndTestSuite_TotalDurationKey],
             closeTo([testAState duration] + [testBState duration], 0.1f));
}

- (void)testAddTestsFromString
{
  OCTestSuiteEventState *state =
    [[[OCTestSuiteEventState alloc] initWithName:@"ATestSuite"] autorelease];

  [state addTestsFromArray:@[@"ATestSuite/aTestMethod", @"BTestSuite/bTestMethod"]];

  NSArray *tests = [state tests];
  assertThat(tests, hasCountOf(2));
  assertThat([tests[0] testName], is(@"-[ATestSuite aTestMethod]"));
  assertThat([tests[1] testName], is(@"-[BTestSuite bTestMethod]"));
}

- (void)testGetTestByName
{
  OCTestSuiteEventState *state =
    [[[OCTestSuiteEventState alloc] initWithName:@"ATestSuite"] autorelease];
  OCTestEventState *testAState =
  [[[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"] autorelease];
  OCTestEventState *testBState =
  [[[OCTestEventState alloc] initWithInputName:@"ATestClass/bTestMethod"] autorelease];

  [state addTest:testAState];
  [state addTest:testBState];

  assertThat([state getTestWithTestName:@"-[ATestClass aTestMethod]"],
             equalTo(testAState));
  assertThat([state getTestWithTestName:@"-[ATestClass bTestMethod]"],
             equalTo(testBState));
  assertThat([state getTestWithTestName:@"-[NoSuch test]"], nilValue());
}

- (void)testFinishTests
{
  EventBuffer *eventBuffer = [[[EventBuffer alloc] init] autorelease];

  OCTestSuiteEventState *state =
    [[[OCTestSuiteEventState alloc] initWithName:@"ATestSuite" reporters:@[eventBuffer]] autorelease];
  OCTestEventState *testAState =
  [[[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"] autorelease];
  OCTestEventState *testBState =
  [[[OCTestEventState alloc] initWithInputName:@"ATestClass/bTestMethod"] autorelease];

  [state addTest:testAState];
  [state addTest:testBState];

  [state beginTestSuite];
  [testAState stateBeginTest];
  [testAState stateEndTest:YES result:@"success"];
  [testBState stateBeginTest];

  assertThatInteger(state.testCount, equalToInteger(2));
  assertThatInteger(state.totalFailures, equalToInteger(1));

  [state publishEvents];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(2));
  NSDictionary *testEvent = events[0];
  NSDictionary *suiteEvent = events[1];

  assertThat(suiteEvent[kReporter_EndTestSuite_TestCaseCountKey], equalToInt(2));
  assertThat(suiteEvent[kReporter_EndTestSuite_TotalFailureCountKey], equalToInt(1));
  assertThat(suiteEvent[kReporter_EndTestSuite_TotalDurationKey],
             closeTo([testAState duration] + [testBState duration], 0.1f));

  assertThat(testEvent[kReporter_EndTest_SucceededKey], equalToBool(NO));
  assertThat(testEvent[kReporter_EndTest_ResultKey], is(@"error"));
}

- (void)testRunningTest
{
  OCTestSuiteEventState *state =
  [[[OCTestSuiteEventState alloc] initWithName:@"ATestSuite"] autorelease];
  OCTestEventState *testAState =
  [[[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"] autorelease];
  OCTestEventState *testBState =
  [[[OCTestEventState alloc] initWithInputName:@"ATestClass/bTestMethod"] autorelease];

  [state addTest:testAState];
  [state addTest:testBState];

  assertThat([state runningTest], nilValue());

  [state beginTestSuite];
  [testAState stateBeginTest];
  [testAState stateEndTest:YES result:@"failure"];
  [testBState stateBeginTest];

  assertThat([state runningTest], is(testBState));
}

@end
