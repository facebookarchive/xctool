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

#import "TestRunState.h"

#import <QuartzCore/QuartzCore.h>

#import "OCTestEventState.h"
#import "OCTestSuiteEventState.h"
#import "ReporterEvents.h"
#import "XCToolUtil.h"

@interface TestRunState ()
@property (nonatomic, strong) OCTestSuiteEventState *testSuiteState;
@property (nonatomic, strong) OCTestEventState *previousTestState;
@property (nonatomic, copy) NSSet *crashReportsAtStart;
@property (nonatomic, copy) NSMutableString *outputBeforeTestsStart;
@end

@implementation TestRunState

- (instancetype)initWithTests:(NSArray *)testList
                    reporters:(NSArray *)reporters
{
  self = [super init];
  if (self) {
    _testSuiteState =
      [[OCTestSuiteEventState alloc] initWithName:kReporter_TestSuite_TopLevelSuiteName
                                        reporters:reporters];
    [_testSuiteState addTestsFromArray:testList];
    _outputBeforeTestsStart = [[NSMutableString alloc] init];
  }
  return self;
}

- (instancetype)initWithTestSuiteEventState:(OCTestSuiteEventState *)suiteState
{
  self = [super init];
  if (self) {
    _testSuiteState = suiteState;
    _outputBeforeTestsStart = [[NSMutableString alloc] init];
  }
  return self;
}


- (void)setReporters:(NSArray *)reporters
{
  _testSuiteState.reporters = reporters;
}

- (BOOL)allTestsPassed
{
  unsigned int numPassed = 0;
  for (int i = 0; i < [_testSuiteState.tests count]; i++) {
    OCTestEventState *testState = _testSuiteState.tests[i];
    if (testState.isSuccessful) {
      numPassed++;
    }
  }

  return (numPassed == [_testSuiteState testCount]) && _testSuiteState.isFinished;
}

- (void)prepareToRun
{
  NSAssert(_crashReportsAtStart == nil, @"Should not have set yet.");
  _crashReportsAtStart = [NSSet setWithArray:[self collectCrashReportPaths]];
}

- (void)publishEventToReporters:(NSDictionary *)event
{
  PublishEventToReporters(_testSuiteState.reporters, event);
}

- (void)outputBeforeTestBundleStarts:(NSDictionary *)event
{
  [_outputBeforeTestsStart appendString:event[kReporter_SimulatorOutput_OutputKey]];
}

- (void)beginTestSuite:(NSDictionary *)event
{
  NSAssert([event[kReporter_BeginTestSuite_SuiteKey] isEqualTo:kReporter_TestSuite_TopLevelSuiteName],
           @"Expected to begin test suite `%@', got `%@'",
           kReporter_TestSuite_TopLevelSuiteName, event[kReporter_BeginTestSuite_SuiteKey]);

  if ([_testSuiteState isStarted]) {
    return;
  }

  [_testSuiteState beginTestSuite:event];
}

- (void)beginTest:(NSDictionary *)event
{
  NSAssert(_testSuiteState, @"Starting test without a test suite");
  NSString *testName = event[kReporter_BeginTest_TestKey];
  OCTestEventState *state = [_testSuiteState getTestWithTestName:testName];
  NSAssert(state, @"Can't find test state for '%@', check senTestList", testName);
  [state stateBeginTest];

  [self publishEventToReporters:event];
}

- (void)endTest:(NSDictionary *)inEvent
{
  NSMutableDictionary *event = [inEvent mutableCopy];
  NSAssert(_testSuiteState, @"Ending test without a test suite");
  NSString *testName = event[kReporter_EndTest_TestKey];
  OCTestEventState *state = [_testSuiteState getTestWithTestName:testName];
  NSAssert(state, @"Can't find test state for '%@', check senTestList", testName);
  [state stateEndTest:[event[kReporter_EndTest_SucceededKey] intValue]
               result:event[kReporter_EndTest_ResultKey]
             duration:[event[kReporter_EndTest_TotalDurationKey] doubleValue]];

  event[kReporter_EndTest_OutputKey] = [state outputAlreadyPublished];

  if (_previousTestState) {
    _previousTestState = nil;
  }
  _previousTestState = state;

  [self publishEventToReporters:event];
}

- (void)endTestSuite:(NSDictionary *)event
{
  [_testSuiteState endTestSuite:event];
}

- (void)testOutput:(NSDictionary *)event
{
  OCTestEventState *test = [_testSuiteState runningTest];
  NSAssert(test, @"Got output with no test running");
  [test stateTestOutput:event[kReporter_SimulatorOutput_OutputKey]];

  NSDictionary *testOutputEvent = @{
    kReporter_Event_Key: kReporter_Events_TestOuput,
    kReporter_TestOutput_OutputKey: event[kReporter_SimulatorOutput_OutputKey],
    kReporter_TimestampKey: event[kReporter_TimestampKey],
  };

  [self publishEventToReporters:testOutputEvent];
}

- (void)simulatorOutput:(NSDictionary *)event
{
  if ([_testSuiteState runningTest]) {
    [self testOutput:event];
  } else {
    [self outputBeforeTestBundleStarts:event];
  }
}

- (void)handleStartupError:(NSString *)startupError
{
  [[_testSuiteState unstartedTests] makeObjectsPerformSelector:@selector(appendOutput:)
                                                    withObject:[NSString stringWithFormat:@"Test did not run: %@", startupError]];

  // Insert a place holder test to hold detailed error info.
  OCTestEventState *fakeTest = [[OCTestEventState alloc] initWithInputName:@"TEST_BUNDLE/FAILED_TO_START"];
  // Append crash reports (if any) to the place holder test.
  NSString *fakeTestOutput = [NSString stringWithFormat:
                              @"There was a problem starting the test bundle: %@\n"
                              @"\n"
                              @"%@",
                              startupError,
                              [self collectCrashReports:_crashReportsAtStart]];
  fakeTestOutput = [fakeTestOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  [fakeTest appendOutput:fakeTestOutput];
  [_testSuiteState insertTest:fakeTest atIndex:0];
}

- (void)handleCrashBeforeAnyTestsRanWithOtherErrors:(NSString *)otherErrors
{
  // The test runner crashed before any tests ran.
  OCTestEventState *fakeTest = [[OCTestEventState alloc] initWithInputName:@"FAILED_BEFORE/TESTS_RAN"];
  [_testSuiteState insertTest:fakeTest atIndex:0];

  // All tests should include this message.
  NSString *output = @"Test did not run: the test bundle stopped running or crashed before the test suite started.";
  [_testSuiteState.tests makeObjectsPerformSelector:@selector(appendOutput:)
                                         withObject:output];

  // And, our "place holder" test should have a more detailed message about
  // what we think went wrong.
  NSString *fakeTestOutput = [NSString stringWithFormat:@"%@\n%@\n%@",
                              otherErrors ?: @"",
                              _outputBeforeTestsStart,
                              [self collectCrashReports:_crashReportsAtStart]];
  fakeTestOutput = [fakeTestOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  [fakeTest appendOutput:[@"\n\n" stringByAppendingString:fakeTestOutput]];
}

- (void)handleCrashDuringTest
{
  // The test runner crashed while running a particular test.
  NSString *outputForCrashingTest = [NSString stringWithFormat:
                                     @"Test crashed while running.\n\n%@",
                                     [self collectCrashReports:_crashReportsAtStart]];
  outputForCrashingTest = [outputForCrashingTest stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  [[_testSuiteState runningTest] appendOutput:outputForCrashingTest];
  [[_testSuiteState runningTest] publishEvents];
}

- (void)handleCrashAfterTest
{
  // The test runner crashed after a previous test completed but before the
  // next test begain.  This usually means the last test over-released
  // something, but it could be a lot of things.
  NSAssert(_previousTestState != nil, @"We should have some info on the last test that ran.");
  NSUInteger previousTestStateIndex = [[_testSuiteState tests] indexOfObject:_previousTestState];

  // Insert a place-holder test to hold information on the crash.
  NSString *fakeTestName = [NSString stringWithFormat:@"%@/%@_MAYBE_CRASHED",
                            [_previousTestState className],
                            [_previousTestState methodName]];
  NSString *fakeTestOutput = [NSString stringWithFormat:
                              @"The test bundle stopped running or crashed immediately after running '%@'.  Even though that test finished, it's "
                              @"likely responsible for the crash.\n"
                              @"\n"
                              @"%@",
                              [_previousTestState testName],
                              [self collectCrashReports:_crashReportsAtStart]];
  fakeTestOutput = [fakeTestOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  OCTestEventState *fakeTest = [[OCTestEventState alloc] initWithInputName:fakeTestName];
  [fakeTest appendOutput:fakeTestOutput];

  [_testSuiteState insertTest:fakeTest atIndex:previousTestStateIndex + 1];
}

- (void)didFinishRunWithStartupError:(NSString *)startupError otherErrors:(NSString *)otherErrors
{
  if (![_testSuiteState isStarted] && startupError != nil) {
    [self handleStartupError:startupError];
  } else if ((![_testSuiteState isStarted] && startupError == nil) ||
             ([_testSuiteState isStarted] && [_testSuiteState unstartedTests].count == [_testSuiteState testCount])) {
    [self handleCrashBeforeAnyTestsRanWithOtherErrors:otherErrors];
  } else if (![_testSuiteState isFinished] && [_testSuiteState runningTest] != nil) {
    [self handleCrashDuringTest];
    [_testSuiteState publishEventsForFinishedTests];
    return;
  } else if (![_testSuiteState isFinished] &&
             [_testSuiteState runningTest] == nil) {
    [self handleCrashAfterTest];
  }

  [_testSuiteState publishEvents];
}

- (NSArray *)collectCrashReportPaths
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray *diagnosticReportsPaths = @[
    [@"~/Library/Logs/DiagnosticReports" stringByStandardizingPath],
    @"/Library/Logs/DiagnosticReports",
  ];

  NSMutableArray *matchingContents = [NSMutableArray array];
  for (NSString *diagnosticReportsPath in diagnosticReportsPaths) {
    BOOL isDirectory = NO;
    BOOL fileExists = [fm fileExistsAtPath:diagnosticReportsPath
                               isDirectory:&isDirectory];
    if (!fileExists || !isDirectory) {
      continue;
    }

    NSDirectoryEnumerator *enumerator = [fm enumeratorAtURL:[NSURL fileURLWithPath:diagnosticReportsPath]
                                 includingPropertiesForKeys:nil
                                                    options:NSDirectoryEnumerationSkipsHiddenFiles
                                               errorHandler:nil];
    NSURL *fileUrl = nil;
    while ((fileUrl = [enumerator nextObject])) {
      if ([[fileUrl pathExtension] isEqualToString:@"crash"]) {
        [matchingContents addObject:fileUrl];
      }
    }
  }

  return matchingContents;
}

- (NSString *)concatenatedCrashReports:(NSArray *)reports
{
  NSMutableString *buffer = [NSMutableString string];

  for (NSURL *fileURL in reports) {
    NSString *crashReportText = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:nil];
    // Throw out everything below "Binary Images" - we mostly just care about the thread backtraces.
    NSRange range = [crashReportText rangeOfString:@"\nBinary Images:"];
    if (!crashReportText || range.location == NSNotFound) {
      continue;
    }
    NSString *minimalCrashReportText = [crashReportText substringToIndex:range.location];
    [buffer appendFormat:@"CRASH REPORT: %@\n\n", [fileURL lastPathComponent]];
    [buffer appendString:minimalCrashReportText];
    [buffer appendString:@"\n"];
  }

  return buffer;
}

- (NSString *)collectCrashReports:(NSSet *)crashReportsAtStart
{
  // Wait for a moment to see if a crash report shows up.
  NSSet *crashReportsAtEnd = [NSSet setWithArray:[self collectCrashReportPaths]];
  CFTimeInterval start = CACurrentMediaTime();

  while (!IsRunningUnderTest() &&
         [crashReportsAtEnd isEqualToSet:crashReportsAtStart] &&
         (CACurrentMediaTime() - start < 10.0)) {
    [NSThread sleepForTimeInterval:0.25];
    crashReportsAtEnd = [NSSet setWithArray:[self collectCrashReportPaths]];
  }

  NSMutableSet *crashReportsGenerated = [NSMutableSet setWithSet:crashReportsAtEnd];
  [crashReportsGenerated minusSet:crashReportsAtStart];
  NSString *concatenatedCrashReports = [self concatenatedCrashReports:[crashReportsGenerated allObjects]];
  return concatenatedCrashReports;
}

@end
