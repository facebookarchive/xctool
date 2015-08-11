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
#import "OCTestEventState.h"
#import "OCTestSuiteEventState.h"
#import "ReporterEvents.h"
#import "TestUtil.h"

static NSDictionary *BeginEventForTestSuiteWithTestName(NSString * testName)
{
  return EventDictionaryWithNameAndContent(kReporter_Events_BeginTestSuite,
                                           @{kReporter_BeginTestSuite_SuiteKey:testName});
}

static NSDictionary *EndEventForTestSuiteWithTestName(NSString * testName)
{
  return EventDictionaryWithNameAndContent(kReporter_Events_EndTestSuite,
                                           @{kReporter_EndTestSuite_SuiteKey:testName});
}

@interface OCTestSuiteEventStateTests : XCTestCase

@end

@implementation OCTestSuiteEventStateTests

- (void)testInitWithEvent
{
  OCTestSuiteEventState *state =
    [[OCTestSuiteEventState alloc] initWithName:@"ATestSuite"];
  assertThat([state testName], is(@"ATestSuite"));
  assertThatInteger([[state tests] count], equalToInteger(0));
}

- (void)testInitWithName
{
  OCTestSuiteEventState *state =
    [[OCTestSuiteEventState alloc] initWithName:@"ATestSuite"];

  assertThat([state testName], is(@"ATestSuite"));
}

- (void)testPublishFromStarted
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  OCTestSuiteEventState *state =
  [[OCTestSuiteEventState alloc] initWithName:@"ATestSuite" reporters:@[eventBuffer]];

  assertThatBool(state.isStarted, isFalse());
  assertThatBool(state.isFinished, isFalse());

  [state beginTestSuite:BeginEventForTestSuiteWithTestName(state.testName)];

  assertThatBool(state.isStarted, isTrue());
  assertThatBool(state.isFinished, isFalse());

  [state publishEvents];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(2));
  assertThat(events[0][@"event"], is(kReporter_Events_BeginTestSuite));
  assertThat(events[0][kReporter_BeginTestSuite_SuiteKey], is(@"ATestSuite"));
  assertThat(events[1][@"event"], is(kReporter_Events_EndTestSuite));
  assertThat(events[1][kReporter_EndTestSuite_SuiteKey], is(@"ATestSuite"));
  assertThat(events[1][kReporter_EndTestSuite_TestCaseCountKey], is(@0));
  assertThat(events[1][kReporter_EndTestSuite_TotalFailureCountKey], is(@0));
  assertThat(events[1][kReporter_EndTestSuite_UnexpectedExceptionCountKey], is(@0));
  assertThatDouble([state totalDuration],
                   closeTo([events[1][kReporter_EndTestSuite_TotalDurationKey] doubleValue], 0.01f));
  assertThat(events[1][kReporter_EndTestSuite_TestDurationKey], is(@([state testDuration])));

  assertThatBool(state.isStarted, isTrue());
  assertThatBool(state.isFinished, isTrue());
}

- (void)testPublishFromNotStarted
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  OCTestSuiteEventState *state =
    [[OCTestSuiteEventState alloc] initWithName:@"ATestSuite" reporters:@[eventBuffer]];

  assertThatBool(state.isStarted, isFalse());
  assertThatBool(state.isFinished, isFalse());

  [state publishEvents];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(2));
  assertThat(events[0][@"event"], is(kReporter_Events_BeginTestSuite));
  assertThat(events[0][kReporter_BeginTestSuite_SuiteKey], is(@"ATestSuite"));
  assertThat(events[1][@"event"], is(kReporter_Events_EndTestSuite));
  assertThat(events[1][kReporter_EndTestSuite_SuiteKey], is(@"ATestSuite"));
  assertThat(events[1][kReporter_EndTestSuite_TestCaseCountKey], is(@0));
  assertThat(events[1][kReporter_EndTestSuite_TotalFailureCountKey], is(@0));
  assertThat(events[1][kReporter_EndTestSuite_UnexpectedExceptionCountKey], is(@0));
  assertThatDouble([state totalDuration],
                   closeTo([events[1][kReporter_EndTestSuite_TotalDurationKey] doubleValue], 0.01f));
  assertThat(events[1][kReporter_EndTestSuite_TestDurationKey], is(@([state testDuration])));

  assertThatBool(state.isStarted, isTrue());
  assertThatBool(state.isFinished, isTrue());
}

- (void)testFromFinished
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  OCTestSuiteEventState *state =
    [[OCTestSuiteEventState alloc] initWithName:@"ATestSuite"];

  assertThatBool(state.isStarted, isFalse());
  assertThatBool(state.isFinished, isFalse());

  [state beginTestSuite:BeginEventForTestSuiteWithTestName(state.testName)];
  [state endTestSuite:EndEventForTestSuiteWithTestName(state.testName)];

  [state publishEvents];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(0));
}

- (void)testTestDuration
{
  OCTestSuiteEventState *state =
    [[OCTestSuiteEventState alloc] initWithName:@"ATestSuite"];
  OCTestEventState *testAState =
  [[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"];
  OCTestEventState *testBState =
  [[OCTestEventState alloc] initWithInputName:@"ATestClass/bTestMethod"];

  [state addTest:testAState];
  [state addTest:testBState];

  [state beginTestSuite:BeginEventForTestSuiteWithTestName(state.testName)];
  [testAState stateBeginTest];
  [testAState stateEndTest:YES result:@"success"];
  [testBState stateBeginTest];
  [testBState stateEndTest:NO result:@"failure"];
  testAState.duration = 5.0f;
  testBState.duration = 10.0f;
  [state endTestSuite:EndEventForTestSuiteWithTestName(state.testName)];

  assertThatDouble([state testDuration], closeTo(15.0, 0.1f));
}

- (void)testAddTests
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  OCTestSuiteEventState *state =
    [[OCTestSuiteEventState alloc] initWithName:@"ATestSuite" reporters:@[eventBuffer]];

  OCTestEventState *testAState =
    [[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"];
  OCTestEventState *testBState =
    [[OCTestEventState alloc] initWithInputName:@"ATestClass/bTestMethod"];
  OCTestEventState *testCState =
    [[OCTestEventState alloc] initWithInputName:@"ATestClass/cTestMethod"];

  [state addTest:testAState];
  [state addTest:testBState];
  [state addTest:testCState];

  [state beginTestSuite:BeginEventForTestSuiteWithTestName(state.testName)];
  [testAState stateBeginTest];
  [testAState stateEndTest:YES result:@"success"];
  [testBState stateBeginTest];
  [testBState stateEndTest:NO result:@"failure"];
  [testCState stateBeginTest];
  [testCState stateEndTest:NO result:@"error"];

  assertThatInteger(state.testCount, equalToInteger(3));
  assertThatInteger(state.totalFailures, equalToInteger(1));
  assertThatInteger(state.totalErrors, equalToInteger(1));

  [state publishEvents];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(2));
  assertThat(events[0][@"event"], is(kReporter_Events_BeginTestSuite));
  assertThat(events[0][kReporter_BeginTestSuite_SuiteKey], is(@"ATestSuite"));
  assertThat(events[1][kReporter_EndTestSuite_TestCaseCountKey], equalToInt(3));
  assertThat(events[1][kReporter_EndTestSuite_TotalFailureCountKey], equalToInt(1));
  assertThat(events[1][kReporter_EndTestSuite_UnexpectedExceptionCountKey], equalToInt(1));
  assertThat(events[1][kReporter_EndTestSuite_TotalDurationKey],
             closeTo([testAState duration] + [testBState duration], 0.1f));
}

- (void)testAddTestsFromString
{
  OCTestSuiteEventState *state =
    [[OCTestSuiteEventState alloc] initWithName:@"ATestSuite"];

  [state addTestsFromArray:@[@"ATestSuite/aTestMethod", @"BTestSuite/bTestMethod"]];

  NSArray *tests = [state tests];
  assertThat(tests, hasCountOf(2));
  assertThat([tests[0] testName], is(@"-[ATestSuite aTestMethod]"));
  assertThat([tests[1] testName], is(@"-[BTestSuite bTestMethod]"));
}

- (void)testGetTestByName
{
  OCTestSuiteEventState *state =
    [[OCTestSuiteEventState alloc] initWithName:@"ATestSuite"];
  OCTestEventState *testAState =
  [[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"];
  OCTestEventState *testBState =
  [[OCTestEventState alloc] initWithInputName:@"ATestClass/bTestMethod"];

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
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];

  OCTestSuiteEventState *state =
    [[OCTestSuiteEventState alloc] initWithName:@"ATestSuite" reporters:@[eventBuffer]];
  OCTestEventState *testAState =
  [[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"];
  OCTestEventState *testBState =
  [[OCTestEventState alloc] initWithInputName:@"ATestClass/bTestMethod"];

  [state addTest:testAState];
  [state addTest:testBState];

  [state beginTestSuite:BeginEventForTestSuiteWithTestName(state.testName)];
  [testAState stateBeginTest];
  [testAState stateEndTest:YES result:@"success"];
  [testBState stateBeginTest];

  assertThatInteger(state.testCount, equalToInteger(2));
  assertThatInteger(state.totalErrors, equalToInteger(1));
  assertThatInteger(state.totalFailures, equalToInteger(0));

  [state publishEvents];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(3));
  NSDictionary *testEvent = events[1];
  NSDictionary *suiteEventEnd = events[2];

  assertThat(suiteEventEnd[kReporter_EndTestSuite_TestCaseCountKey], equalToInt(2));
  assertThat(suiteEventEnd[kReporter_EndTestSuite_UnexpectedExceptionCountKey], equalToInt(1));
  assertThat(suiteEventEnd[kReporter_EndTestSuite_TotalFailureCountKey], equalToInt(0));
  assertThat(suiteEventEnd[kReporter_EndTestSuite_TotalDurationKey],
             closeTo([testAState duration] + [testBState duration], 0.1f));

  assertThat(testEvent[kReporter_EndTest_SucceededKey], isFalse());
  assertThat(testEvent[kReporter_EndTest_ResultKey], is(@"error"));
}

- (void)testRunningTest
{
  OCTestSuiteEventState *state =
  [[OCTestSuiteEventState alloc] initWithName:@"ATestSuite"];
  OCTestEventState *testAState =
  [[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"];
  OCTestEventState *testBState =
  [[OCTestEventState alloc] initWithInputName:@"ATestClass/bTestMethod"];

  [state addTest:testAState];
  [state addTest:testBState];

  assertThat([state runningTest], nilValue());

  [state beginTestSuite:BeginEventForTestSuiteWithTestName(state.testName)];
  [testAState stateBeginTest];
  [testAState stateEndTest:YES result:@"failure"];
  [testBState stateBeginTest];

  assertThat([state runningTest], is(testBState));
}

- (void)testFailedAndErroredTests
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];

  OCTestSuiteEventState *state =
  [[OCTestSuiteEventState alloc] initWithName:@"ATestSuite" reporters:@[eventBuffer]];
  OCTestEventState *testAState =
  [[OCTestEventState alloc] initWithInputName:@"ATestClass/aTestMethod"];
  OCTestEventState *testBState =
  [[OCTestEventState alloc] initWithInputName:@"ATestClass/bTestMethod"];

  [state addTest:testAState];
  [state addTest:testBState];

  NSDictionary *beginEvent = EventDictionaryWithNameAndContent(kReporter_Events_BeginTestSuite,
                               @{kReporter_BeginTestSuite_SuiteKey:state.testName});
  [state beginTestSuite:beginEvent];
  [testAState stateBeginTest];
  [testAState stateEndTest:YES result:@"failure"];
  [testBState stateBeginTest];
  [testBState stateEndTest:YES result:@"error"];

  assertThatInteger(state.testCount, equalToInteger(2));
  assertThatInteger(state.totalFailures, equalToInteger(1));
  assertThatInteger(state.totalErrors, equalToInteger(1));

  [state publishEvents];
  NSArray *events = eventBuffer.events;

  assertThatInteger([events count], equalToInteger(2));
  NSDictionary *endEvent = events[1];

  assertThat(endEvent[kReporter_EndTestSuite_TestCaseCountKey], equalToInt(2));
  assertThat(endEvent[kReporter_EndTestSuite_TotalFailureCountKey], equalToInt(1));
  assertThat(endEvent[kReporter_EndTestSuite_UnexpectedExceptionCountKey], equalToInt(1));
  assertThat(endEvent[kReporter_EndTestSuite_TotalDurationKey],
             closeTo([testAState duration] + [testBState duration], 0.1f));
  assertThat(endEvent[kReporter_EndTestSuite_TestDurationKey],
             closeTo([testAState duration] + [testBState duration], 0.1f));
}

@end
