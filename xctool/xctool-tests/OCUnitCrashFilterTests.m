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

#import "OCUnitCrashFilter.h"
#import "OCUnitTestRunner.h"

@interface FakeReporter : NSObject

@property (nonatomic, retain) NSMutableArray *events;

@end

@implementation FakeReporter

+ (FakeReporter *)fakeReporterThatSavesTo:(NSMutableArray *)saveToArr
{
  FakeReporter *fake = [[[FakeReporter alloc] init] autorelease];
  fake.events = saveToArr;
  return fake;
}

- (void)handleEvent:(NSDictionary *)event
{
  [self.events addObject:event];
}

@end

@interface OCUnitCrashFilterTests : SenTestCase
@end

@implementation OCUnitCrashFilterTests

- (OCUnitCrashFilter *)filterWithEvents:(NSArray *)events
{
  OCUnitCrashFilter *filter = [[[OCUnitCrashFilter alloc] init] autorelease];

  for (NSDictionary *event in events) {
    [filter handleEvent:event];
  }

  return filter;
}

- (void)testGoodTestRunDoesNotHaveAnUnfinishedTest
{
  OCUnitCrashFilter *filter =
    [self filterWithEvents:@[
     @{@"event" : @"begin-test-suite", @"suite" : @"All tests"},
     @{@"event" : @"begin-test-suite", @"suite" : @"/path/to/TestProject-LibraryTests.octest(Tests)"},
     @{@"event" : @"begin-test-suite", @"suite" : @"OtherTests"},
     @{@"event" : @"begin-test", @"test" : @"-[OtherTests testSomething]"},
     @{@"event" : @"end-test", @"test" : @"-[OtherTests testSomething]", @"succeeded" : @YES, @"output" : @"", @"totalDuration" : @1.0},
     @{@"event" : @"end-test-suite", @"suite" : @"OtherTests", @"testCaseCount" : @1, @"totalFailureCount" : @0, @"totalDuration" : @1.0, @"testDuration" : @1.0, @"unexpectedExceptionCount" : @0},
     @{@"event" : @"end-test-suite", @"suite" : @"/path/to/TestProject-LibraryTests.octest(Tests)", @"testCaseCount" : @1, @"totalFailureCount" : @0, @"totalDuration" : @1.0, @"testDuration" : @1.0, @"unexpectedExceptionCount" : @0},
     @{@"event" : @"end-test-suite", @"suite" : @"All tests", @"testCaseCount" : @1, @"totalFailureCount" : @0, @"totalDuration" : @1.0, @"testDuration" : @1.0, @"unexpectedExceptionCount" : @0},
     ]];
  assertThatBool([filter testRunWasUnfinished], equalToBool(NO));
}

- (void)testCanGenerateCorrectEventsWhenTestNeverFinishes
{
  OCUnitCrashFilter *filter =
    [self filterWithEvents:@[
     @{@"event" : @"begin-test-suite", @"suite" : @"All tests"},
     @{@"event" : @"begin-test-suite", @"suite" : @"/path/to/TestProject-LibraryTests.octest(Tests)"},
     @{@"event" : @"begin-test-suite", @"suite" : @"OtherTests"},
     @{@"event" : @"begin-test", @"test" : @"-[OtherTests testSomething]", @"className" : @"OtherTests", @"methodName" : @"testSomething"},
     ]];
  assertThatBool([filter testRunWasUnfinished], equalToBool(YES));
  assertThat(filter.currentTestEvent, notNilValue());

  NSMutableArray *generatedEvents = [NSMutableArray array];
  [filter fireEventsToSimulateTestRunFinishing:@[[FakeReporter fakeReporterThatSavesTo:generatedEvents]]
                               fullProductName:@"TestProject-LibraryTests.octest"
                      concatenatedCrashReports:@"CONCATENATED_CRASH_REPORTS_GO_HERE"];

  assertThatInteger((generatedEvents.count), equalToInteger(5));

  // We should see another 'test-output' event with the crash report text.
  assertThat(generatedEvents[0][@"event"], equalTo(@"test-output"));
  assertThat(generatedEvents[0][@"output"], equalTo(@"CONCATENATED_CRASH_REPORTS_GO_HERE"));

  // The test should get marked as a failure
  assertThat(generatedEvents[1][@"event"], equalTo(@"end-test"));
  assertThat(generatedEvents[1][@"test"], equalTo(@"-[OtherTests testSomething]"));
  assertThat(generatedEvents[1][@"className"], equalTo(@"OtherTests"));
  assertThat(generatedEvents[1][@"methodName"], equalTo(@"testSomething"));
  assertThat(generatedEvents[1][@"succeeded"], equalTo(@NO));

  // And 'end-test-suite' events should get sent for each of the suites we were in.
  assertThat(generatedEvents[2][@"event"], equalTo(@"end-test-suite"));
  assertThat(generatedEvents[3][@"event"], equalTo(@"end-test-suite"));
  assertThat(generatedEvents[4][@"event"], equalTo(@"end-test-suite"));
}

- (void)testCanGenerateCorrectEventsWhenTestFinishesButCrashesImmediatelyAfterwards
{
  // This is a common case where we've over-released something.  When OCUnit runs
  // a test, it creates a new NSAutoreleasePool before starting the test, and drains
  // it immediately afterwards.  If we over-release something that's already been
  // added to the autorelease pool, then the test runner will crash with EXC_BAD_ACCESS
  // as soon as the pool is drained.

  OCUnitCrashFilter *filter =
    [self filterWithEvents:@[
     @{@"event" : @"begin-test-suite", @"suite" : @"All tests"},
     @{@"event" : @"begin-test-suite", @"suite" : @"/path/to/TestProject-LibraryTests.octest(Tests)"},
     @{@"event" : @"begin-test-suite", @"suite" : @"OtherTests"},
     @{@"event" : @"begin-test", @"test" : @"-[OtherTests testSomething]", @"className" : @"OtherTests", @"methodName" : @"testSomething"},
     @{@"event" : @"end-test", @"test" : @"-[OtherTests testSomething]", @"className" : @"OtherTests", @"methodName" : @"testSomething", @"succeeded" : @YES, @"output" : @"", @"totalDuration" : @1.0},
     ]];
  assertThatBool([filter testRunWasUnfinished], equalToBool(YES));

  NSMutableArray *generatedEvents = [NSMutableArray array];
  [filter fireEventsToSimulateTestRunFinishing:@[[FakeReporter fakeReporterThatSavesTo:generatedEvents]]
                               fullProductName:@"TestProject-LibraryTests.octest"
                      concatenatedCrashReports:@"CONCATENATED_CRASH_REPORTS_GO_HERE"];

  assertThatInteger((generatedEvents.count), equalToInteger(6));

  // The test should get marked as a failure
  assertThat(generatedEvents[0][@"event"], equalTo(@"begin-test"));
  assertThat(generatedEvents[0][@"test"], equalTo(@"TestProject-LibraryTests.octest_CRASHED"));

  assertThat(generatedEvents[1][@"event"], equalTo(@"test-output"));
  assertThat(generatedEvents[1][@"output"], startsWith(@"The tests crashed"));

  assertThat(generatedEvents[2][@"event"], equalTo(@"end-test"));
  assertThat(generatedEvents[2][@"test"], equalTo(@"TestProject-LibraryTests.octest_CRASHED"));
  assertThat(generatedEvents[2][@"className"], equalTo(@"TestProject-LibraryTests.octest"));
  assertThat(generatedEvents[2][@"methodName"], equalTo(@"CRASHED"));
  assertThat(generatedEvents[2][@"succeeded"], equalTo(@NO));

  // And 'end-test-suite' events should get sent for each of the suites we were in.
  assertThat(generatedEvents[3][@"event"], equalTo(@"end-test-suite"));
  assertThat(generatedEvents[4][@"event"], equalTo(@"end-test-suite"));
  assertThat(generatedEvents[5][@"event"], equalTo(@"end-test-suite"));
}

@end
