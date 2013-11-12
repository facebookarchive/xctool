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

#import "TestRunState.h"

#import <QuartzCore/QuartzCore.h>

#import "ReporterEvents.h"
#import "OCTestSuiteEventState.h"
#import "OCTestEventState.h"
#import "XCToolUtil.h"

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
  }
  return self;
}

- (void)dealloc
{
  [_testSuiteState release];
  [_previousTestState release];
  [_crashReportsAtStart release];
  [super dealloc];
}

- (void)setReporters:(NSArray *)reporters
{
  _testSuiteState.reporters = reporters;
}

- (void)prepareToRun
{
  NSAssert(_crashReportsAtStart == nil, @"Should not have set yet.");
  _crashReportsAtStart = [[NSSet setWithArray:[self collectCrashReportPaths]] retain];
}

- (void)finishedRun:(BOOL)unexpectedTermination
              error:(NSString *)error
{
  [self didFinishRunWithStartupError:error];
}

- (void)beginTestSuite:(NSDictionary *)event
{
  NSAssert(![_testSuiteState isStarted], @"Test suite already started!");
  NSAssert([event[kReporter_BeginTestSuite_SuiteKey] isEqualTo:kReporter_TestSuite_TopLevelSuiteName],
           @"Expected to begin test suite `%@', got `%@'",
           kReporter_TestSuite_TopLevelSuiteName, event[kReporter_BeginTestSuite_SuiteKey]);

  [_testSuiteState beginTestSuite];
}

- (void)beginTest:(NSDictionary *)event
{
  NSAssert(_testSuiteState, @"Starting test without a test suite");
  NSString *testName = event[kReporter_BeginTest_TestKey];
  OCTestEventState *state = [_testSuiteState getTestWithTestName:testName];
  NSAssert(state, @"Can't find test state for '%@', check senTestList", testName);
  [state stateBeginTest];
}

- (void)endTest:(NSDictionary *)event
{
  NSAssert(_testSuiteState, @"Ending test without a test suite");
  NSString *testName = event[kReporter_EndTest_TestKey];
  OCTestEventState *state = [_testSuiteState getTestWithTestName:testName];
  NSAssert(state, @"Can't find test state for '%@', check senTestList", testName);
  [state stateEndTest:[event[kReporter_EndTest_SucceededKey] intValue]
               result:event[kReporter_EndTest_ResultKey]
             duration:[event[kReporter_EndTest_TotalDurationKey] doubleValue]];

  if (_previousTestState) {
    [_previousTestState release];
    _previousTestState = nil;
  }
  _previousTestState = [state retain];
}

- (void)endTestSuite:(NSDictionary *)event
{
  [_testSuiteState endTestSuite];
}

- (void)testOutput:(NSDictionary *)event
{
  OCTestEventState *test = [_testSuiteState runningTest];
  NSAssert(test, @"Got output with no test running");
  [test stateTestOutput:event[kReporter_TestOutput_OutputKey]];
}

- (void)handleStartupError:(NSString *)startupError
{
  [[_testSuiteState unstartedTests] makeObjectsPerformSelector:@selector(appendOutput:)
                                                    withObject:[NSString stringWithFormat:@"Test did not run: %@", startupError]];
}

- (void)handleCrashBeforeAnyTestsRan
{
  // The test runner crashed before any tests ran.
  OCTestEventState *fakeTest = [[[OCTestEventState alloc] initWithInputName:@"FAILED_BEFORE/TESTS_RAN"] autorelease];
  [_testSuiteState insertTest:fakeTest atIndex:0];

  // All tests should include this message.
  [_testSuiteState.tests makeObjectsPerformSelector:@selector(appendOutput:)
                                         withObject:@"Test did not run: the test bundle stopped running or crashed before the test suite started."];

  // And, our "place holder" test should have a more detailed message about
  // what we think went wrong.
  NSString *fakeTestOutput = [NSString stringWithFormat:
                              @"The crash was triggered before any test code ran.  You might look at "
                              @"Obj-C class 'initialize' or 'load' methods, or C-style constructor functions "
                              @"as possible causes.\n"
                              @"%@",
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
  NSString *outputForOtherTests = [NSString stringWithFormat:
                                   @"Test did not run: the test bundle stopped running or crashed in '%@'.",
                                   [[_testSuiteState runningTest] testName]];

  [[_testSuiteState runningTest] appendOutput:outputForCrashingTest];
  [[_testSuiteState unstartedTests] makeObjectsPerformSelector:@selector(appendOutput:) withObject:outputForOtherTests];
}

- (void)handleCrashAfterTest
{
  // The test runner crashed after a previous test completed but before the
  // next test begain.  This usually means the last test over-released
  // something, but it could be a lot of things.
  NSAssert(_previousTestState != nil, @"We should have some info on the last test that ran.");
  NSUInteger previousTestStateIndex = [[_testSuiteState tests] indexOfObject:_previousTestState];

  // We should annotate all tests that never ran.
  [[_testSuiteState unstartedTests] makeObjectsPerformSelector:@selector(appendOutput:)
                                                    withObject:[NSString stringWithFormat:
                                                                @"Test did not run: the test bundle stopped running or crashed after running '%@'.",
                                                                [_previousTestState testName]]];

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

  OCTestEventState *fakeTest = [[[OCTestEventState alloc] initWithInputName:fakeTestName] autorelease];
  [fakeTest appendOutput:fakeTestOutput];

  [_testSuiteState insertTest:fakeTest atIndex:previousTestStateIndex + 1];
}

- (void)didFinishRunWithStartupError:(NSString *)startupError
{
  if (![_testSuiteState isStarted] && startupError != nil) {
    [self handleStartupError:startupError];
  } else if ((![_testSuiteState isStarted] && startupError == nil) ||
             ([_testSuiteState isStarted] && [_testSuiteState unstartedTests].count == [_testSuiteState testCount])) {
    [self handleCrashBeforeAnyTestsRan];
  } else if (![_testSuiteState isFinished] && [_testSuiteState runningTest] != nil) {
    [self handleCrashDuringTest];
  } else if (![_testSuiteState isFinished] &&
             [_testSuiteState runningTest] == nil) {
    [self handleCrashAfterTest];
  }

  [_testSuiteState publishEvents];
}

- (NSArray *)collectCrashReportPaths
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *diagnosticReportsPath = [@"~/Library/Logs/DiagnosticReports" stringByStandardizingPath];

  BOOL isDirectory = NO;
  BOOL fileExists = [fm fileExistsAtPath:diagnosticReportsPath
                             isDirectory:&isDirectory];
  if (!fileExists || !isDirectory) {
    return @[];
  }

  NSError *error = nil;
  NSArray *allContents = [fm contentsOfDirectoryAtPath:diagnosticReportsPath
                                                 error:&error];
  NSAssert(error == nil, @"Failed getting contents of directory: %@", error);

  NSMutableArray *matchingContents = [NSMutableArray array];

  for (NSString *path in allContents) {
    if ([[path pathExtension] isEqualToString:@"crash"]) {
      NSString *fullPath = [[@"~/Library/Logs/DiagnosticReports" stringByAppendingPathComponent:path] stringByStandardizingPath];
      [matchingContents addObject:fullPath];
    }
  }

  return matchingContents;
}

- (NSString *)concatenatedCrashReports:(NSArray *)reports
{
  NSMutableString *buffer = [NSMutableString string];

  for (NSString *path in reports) {
    NSString *crashReportText = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    // Throw out everything below "Binary Images" - we mostly just care about the thread backtraces.
    NSString *minimalCrashReportText = [crashReportText substringToIndex:[crashReportText rangeOfString:@"\nBinary Images:"].location];

    [buffer appendFormat:@"CRASH REPORT: %@\n\n", [path lastPathComponent]];
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
