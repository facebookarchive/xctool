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
  if (unexpectedTermination) {
    [self handleEarlyTermination:_crashReportsAtStart error: error];
  }
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

- (void)handleEarlyTermination:(NSSet *)crashReportsAtStart
                         error:(NSString *)error
{
  if ([_testSuiteState isFinished]) {
    // Normally we'd insert a failing test to advertise the crash, but the test
    // suite has already finished so there's no active suite that we can insert
    // the failure into.
    NSLog(@"WARNING: Test suite crashed after finishing, strange indeed");
    return;
  }

  NSString *summaryTestOutput = @"";
  NSString *extendedTestOutput = [NSString stringWithFormat:
                                  @"\n"
                                  @"%@",
                                  [self collectCrashReports:crashReportsAtStart]];

  // If provided, use the specified error message.
  // Otherwise, create a summary based on the inferred reason for the crash
  if (error) {
    summaryTestOutput = error;
  } else if (![_testSuiteState isStarted]) {
    summaryTestOutput = @"The test binary crashed before starting a test-suite\n";
  } else if ([_testSuiteState runningTest]) {
    summaryTestOutput = [NSString stringWithFormat:
                         @"Test `%@` crashed binary while running\n", [[_testSuiteState runningTest] testName]];
  } else if (_previousTestState) {
    summaryTestOutput = [NSString stringWithFormat:
                         @"The tests crashed immediately after running '%@'.  Even though that test finished, it's "
                         @"likely responsible for the crash.\n",
                         [_previousTestState testName]];
    extendedTestOutput = [NSString stringWithFormat:
                          @"\nTip: Consider re-running this test in Xcode with NSZombieEnabled=YES.  A common cause for "
                          @"these kinds of crashes is over-released objects.  OCUnit creates a NSAutoreleasePool "
                          @"before starting your test and drains it at the end of your test.  If an object has been "
                          @"over-released, it'll trigger an EXC_BAD_ACCESS crash when draining the pool.\n"
                          @"\n"
                          @"%@",
                          [self collectCrashReports:crashReportsAtStart]];
  } else {
    summaryTestOutput = @"The test binary crashed after starting a test-suite but before starting a test\n";
  }

  [self publishTestOutputWithSummary:summaryTestOutput extended:extendedTestOutput];
}

- (void)publishTestOutputWithSummary:(NSString *)summary extended:(NSString *)extended
{
  NSMutableArray *unfinishedTests =
  [[[[_testSuiteState tests] filteredArrayUsingPredicate:
    [NSPredicate predicateWithBlock:^BOOL(OCTestEventState *test, NSDictionary *bindings) {
    return ![test isFinished];
  }]] mutableCopy] autorelease];

  if ([unfinishedTests count] > 0) {
    // The next test to run gets the full debug output
    OCTestEventState *nextTest = unfinishedTests[0];
    [unfinishedTests removeObjectAtIndex:0];
    [nextTest appendOutput:[summary stringByAppendingString:extended]];

    // The rest just get a summary
    [unfinishedTests enumerateObjectsUsingBlock:^(OCTestEventState *testState, NSUInteger idx, BOOL *stop) {
      [testState appendOutput:summary];
    }];
  } else {
    // No tests left to attach the output to, we'll emit a fake one :(
    NSString *fakeTestName;
    if (_previousTestState) {
      fakeTestName = [NSString stringWithFormat:@"%@/%@_MAYBE_CRASHED",
                      [_previousTestState className],
                      [_previousTestState methodName]];
    } else {
      fakeTestName = [NSString stringWithFormat:@"FAILED_AFTER/TESTS_RAN"];
    }
    [self emitFakeTestWithName:fakeTestName
                     andOutput:[summary stringByAppendingString:extended]];
  }

  [_testSuiteState publishEvents];
}

- (void)emitFakeTestWithName:(NSString *)testName andOutput:(NSString *)testOutput
{
  OCTestEventState *fakeTest =
  [[[OCTestEventState alloc] initWithInputName:testName] autorelease];

  [_testSuiteState addTest:fakeTest];
  [fakeTest appendOutput:testOutput];

  [fakeTest publishEvents];
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
