
#import <SenTestingKit/SenTestingKit.h>
#import "TestRunner.h"
#import "OCUnitCrashFilter.h"

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
  assertThat(filter.currentTestEvent, equalTo(nil));
}

- (void)testCanGenerateCorrectEventsWhenTestNeverFinishes
{
  OCUnitCrashFilter *filter =
    [self filterWithEvents:@[
     @{@"event" : @"begin-test-suite", @"suite" : @"All tests"},
     @{@"event" : @"begin-test-suite", @"suite" : @"/path/to/TestProject-LibraryTests.octest(Tests)"},
     @{@"event" : @"begin-test-suite", @"suite" : @"OtherTests"},
     @{@"event" : @"begin-test", @"test" : @"-[OtherTests testSomething]"},
     ]];
  assertThat(filter.currentTestEvent, notNilValue());
  
  NSMutableArray *generatedEvents = [NSMutableArray array];
  [filter fireEventsToSimulateTestRunFinishing:@[[FakeReporter fakeReporterThatSavesTo:generatedEvents]]];
  
  assertThatInteger((generatedEvents.count), equalToInteger(4));
  
  // The test should get marked as a failure
  assertThat(generatedEvents[0][@"event"], equalTo(@"end-test"));
  assertThat(generatedEvents[0][@"test"], equalTo(@"-[OtherTests testSomething]"));
  assertThat(generatedEvents[0][@"succeeded"], equalTo(@NO));

  // And 'end-test-suite' events should get sent for each of the suites we were in.
  assertThat(generatedEvents[1][@"event"], equalTo(@"end-test-suite"));
  assertThat(generatedEvents[2][@"event"], equalTo(@"end-test-suite"));
  assertThat(generatedEvents[3][@"event"], equalTo(@"end-test-suite"));
}

@end
