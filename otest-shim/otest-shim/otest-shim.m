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

#import <Foundation/Foundation.h>

#import <SenTestingKit/SenTestingKit.h>

#import "DuplicateTestNameFix.h"
#import "dyld-interposing.h"
#import "dyld_priv.h"
#import "EventGenerator.h"
#import "ParseTestName.h"
#import "ReporterEvents.h"
#import "SenIsSuperclassOfClassPerformanceFix.h"
#import "SenTestCaseInvokeTestFix.h"
#import "SenTestClassEnumeratorFix.h"
#import "Swizzle.h"
#import "TestingFramework.h"
#import "XCTest.h"

static char *const kEventQueueLabel = "xctool.events";

@interface XCToolAssertionHandler : NSAssertionHandler
@end

@implementation XCToolAssertionHandler

- (void)handleFailureInFunction:(NSString *)functionName
                           file:(NSString *)fileName
                     lineNumber:(NSInteger)line
                    description:(NSString *)format, ...
{
  // Format message
  va_list vl;
  va_start(vl, format);
  NSString *msg = [[[NSString alloc] initWithFormat:format arguments:vl] autorelease];
  va_end(vl);

  // Raise exception
  [NSException raise:NSInternalInconsistencyException format:@"*** Assertion failure in %@, %@:%lld: %@", functionName, fileName, (long long)line, msg];
}

@end

static FILE *__stdout;
static FILE *__stderr;

static NSMutableArray *__testExceptions = nil;
static int __testSuiteDepth = 0;

static NSString *__testScope = nil;

static dispatch_queue_t EventQueue()
{
  static dispatch_queue_t eventQueue = {0};
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    // We'll serialize all events through this queue.
    eventQueue = dispatch_queue_create(kEventQueueLabel, DISPATCH_QUEUE_SERIAL);
  });

  return eventQueue;
}

static void PrintJSON(id JSONObject)
{
  NSError *error = nil;
  NSData *data = [NSJSONSerialization dataWithJSONObject:JSONObject options:0 error:&error];

  if (error) {
    fprintf(__stderr,
            "ERROR: Error generating JSON for object: %s: %s\n",
            [[JSONObject description] UTF8String],
            [[error localizedFailureReason] UTF8String]);
    exit(1);
  }

  fwrite([data bytes], 1, [data length], __stdout);
  fputs("\n", __stdout);
  fflush(__stdout);
}

#pragma mark - XCToolLog function declarations

static void XCToolLog_testSuiteDidStart(NSString *testDescription);
static void XCToolLog_testSuiteDidStop(NSDictionary *json);
static void XCToolLog_testCaseDidStart(NSString *fullTestName);
static void XCToolLog_testCaseDidStop(NSString *fullTestName, NSNumber *unexpectedExceptionCount, NSNumber *failureCount, NSNumber *totalDuration);
static void XCToolLog_testCaseDidFail(NSDictionary *exceptionInfo);

#pragma mark - testSuiteDidStart

static void XCTestLog_testSuiteDidStart(id self, SEL sel, XCTestSuiteRun *run)
{
  NSString *testDescription = [[run test] name];
  XCToolLog_testSuiteDidStart(testDescription);
}

static void SenTestLog_testSuiteDidStart(id self, SEL sel, NSNotification *notification)
{
  SenTestRun *run = [notification run];
  NSString *testDescription = [[run test] description];
  XCToolLog_testSuiteDidStart(testDescription);
}

static void XCToolLog_testSuiteDidStart(NSString *testDescription)
{
  if (__testSuiteDepth == 0) {
    dispatch_sync(EventQueue(), ^{
      PrintJSON(EventDictionaryWithNameAndContent(
        kReporter_Events_BeginTestSuite,
        @{kReporter_BeginTestSuite_SuiteKey : kReporter_TestSuite_TopLevelSuiteName}
      ));
    });
  }
  __testSuiteDepth++;
}

#pragma mark - testSuiteDidStop
static void XCTestLog_testSuiteDidStop(id self, SEL sel, XCTestSuiteRun *run)
{
  XCToolLog_testSuiteDidStop(EventDictionaryWithNameAndContent(
    kReporter_Events_EndTestSuite, @{
      kReporter_EndTestSuite_SuiteKey : kReporter_TestSuite_TopLevelSuiteName,
      kReporter_EndTestSuite_TestCaseCountKey : @([run testCaseCount]),
      kReporter_EndTestSuite_TotalFailureCountKey : @([run totalFailureCount]),
      kReporter_EndTestSuite_UnexpectedExceptionCountKey : @([run unexpectedExceptionCount]),
      kReporter_EndTestSuite_TestDurationKey: @([run testDuration]),
      kReporter_EndTestSuite_TotalDurationKey : @([run totalDuration]),
  }));
}

static void SenTestLog_testSuiteDidStop(id self, SEL sel, NSNotification *notification)
{
  SenTestRun *run = [notification run];
  XCToolLog_testSuiteDidStop(EventDictionaryWithNameAndContent(
    kReporter_Events_EndTestSuite, @{
      kReporter_EndTestSuite_SuiteKey : kReporter_TestSuite_TopLevelSuiteName,
      kReporter_EndTestSuite_TestCaseCountKey : @([run testCaseCount]),
      kReporter_EndTestSuite_TotalFailureCountKey : @([run totalFailureCount]),
      kReporter_EndTestSuite_UnexpectedExceptionCountKey : @([run unexpectedExceptionCount]),
      kReporter_EndTestSuite_TestDurationKey: @([run testDuration]),
      kReporter_EndTestSuite_TotalDurationKey : @([run totalDuration]),
  }));
}

static void XCToolLog_testSuiteDidStop(NSDictionary *json)
{
  __testSuiteDepth--;

  if (__testSuiteDepth == 0) {
    dispatch_sync(EventQueue(), ^{
      PrintJSON(json);
    });
  }
}

#pragma mark - testCaseDidStart

static void XCTestLog_testCaseDidStart(id self, SEL sel, XCTestCaseRun *run)
{
  NSString *fullTestName = [[run test] name];
  XCToolLog_testCaseDidStart(fullTestName);
}

static void SenTestLog_testCaseDidStart(id self, SEL sel, NSNotification *notification)
{
  SenTestRun *run = [notification run];
  NSString *fullTestName = [[run test] description];
  XCToolLog_testCaseDidStart(fullTestName);
}

static void XCToolLog_testCaseDidStart(NSString *fullTestName)
{
  dispatch_sync(EventQueue(), ^{
    NSString *className = nil;
    NSString *methodName = nil;
    ParseClassAndMethodFromTestName(&className, &methodName, fullTestName);

    PrintJSON(EventDictionaryWithNameAndContent(
      kReporter_Events_BeginTest, @{
        kReporter_BeginTest_TestKey : fullTestName,
        kReporter_BeginTest_ClassNameKey : className,
        kReporter_BeginTest_MethodNameKey : methodName,
    }));

    [__testExceptions release];
    __testExceptions = [[NSMutableArray alloc] init];
  });
}

#pragma mark - testCaseDidStop

static void XCTestLog_testCaseDidStop(id self, SEL sel, XCTestCaseRun *run)
{
  NSString *fullTestName = [[run test] name];
  XCToolLog_testCaseDidStop(fullTestName, @([run unexpectedExceptionCount]), @([run failureCount]), @([run totalDuration]));
}

static void SenTestLog_testCaseDidStop(id self, SEL sel, NSNotification *notification)
{
  SenTestRun *run = [notification run];
  NSString *fullTestName = [[run test] description];
  XCToolLog_testCaseDidStop(fullTestName, @([run unexpectedExceptionCount]), @([run failureCount]), @([run totalDuration]));
}

static void XCToolLog_testCaseDidStop(NSString *fullTestName, NSNumber *unexpectedExceptionCount, NSNumber *failureCount, NSNumber *totalDuration)
{
  dispatch_sync(EventQueue(), ^{
    NSString *className = nil;
    NSString *methodName = nil;
    ParseClassAndMethodFromTestName(&className, &methodName, fullTestName);

    BOOL errored = [unexpectedExceptionCount integerValue] > 0;
    BOOL failed = [failureCount integerValue] > 0;
    BOOL succeeded = NO;
    NSString *result;
    if (errored) {
      result = @"error";
    } else if (failed) {
      result = @"failure";
    } else {
      result = @"success";
      succeeded = YES;
    }

    // report test results
    NSArray *retExceptions = [__testExceptions copy];
    NSDictionary *json = EventDictionaryWithNameAndContent(
      kReporter_Events_EndTest, @{
        kReporter_EndTest_TestKey : fullTestName,
        kReporter_EndTest_ClassNameKey : className,
        kReporter_EndTest_MethodNameKey : methodName,
        kReporter_EndTest_SucceededKey: @(succeeded),
        kReporter_EndTest_ResultKey : result,
        kReporter_EndTest_TotalDurationKey : totalDuration,
        kReporter_EndTest_ExceptionsKey : retExceptions,
    });
    [retExceptions release];

    PrintJSON(json);
  });
}

#pragma mark - testCaseDidFail

static void XCTestLog_testCaseDidFail(id self, SEL sel, XCTestCaseRun *run, NSString *description, NSString *file, NSUInteger line)
{
  XCToolLog_testCaseDidFail(@{
    kReporter_EndTest_Exception_FilePathInProjectKey : file ?: @"Unknown File",
    kReporter_EndTest_Exception_LineNumberKey : @(line),
    kReporter_EndTest_Exception_ReasonKey : description,
  });
}

static void SenTestLog_testCaseDidFail(id self, SEL sel, NSNotification *notification)
{

  NSException *entry = [notification exception];
  XCToolLog_testCaseDidFail(@{
    kReporter_EndTest_Exception_FilePathInProjectKey : [entry filePathInProject],
    kReporter_EndTest_Exception_LineNumberKey : [entry lineNumber],
    kReporter_EndTest_Exception_ReasonKey : [entry reason],
  });
}

static void XCToolLog_testCaseDidFail(NSDictionary *exceptionInfo)
{
  dispatch_sync(EventQueue(), ^{
    [__testExceptions addObject:exceptionInfo];
  });
}

#pragma mark - performTest

static void XCPerformTestWithSuppressedExpectedAssertionFailures(id self, SEL origSel, id arg1)
{
  int timeout = [@(getenv("OTEST_SHIM_TEST_TIMEOUT") ?: "0") intValue];

  NSAssertionHandler *handler = [[XCToolAssertionHandler alloc] init];
  NSThread *currentThread = [NSThread currentThread];
  NSMutableDictionary *currentThreadDict = [currentThread threadDictionary];
  [currentThreadDict setObject:handler forKey:NSAssertionHandlerKey];

  if (timeout > 0) {
    int64_t interval = timeout * NSEC_PER_SEC;
    NSString *queueName = [NSString stringWithFormat:@"test.timer.%p", self];
    dispatch_queue_t queue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(source, dispatch_time(DISPATCH_TIME_NOW, interval), 0, 0);
    dispatch_source_set_event_handler(source, ^{
      [NSException raise:NSInternalInconsistencyException
                  format:@"*** Test %@ ran longer than specified test time limit: %d second(s)", self, timeout];
    });
    dispatch_resume(source);

    // Call through original implementation
    objc_msgSend(self, origSel, arg1);

    dispatch_source_cancel(source);
    dispatch_release(source);
    dispatch_release(queue);
  } else {
    // Call through original implementation
    objc_msgSend(self, origSel, arg1);
  }

  // The assertion handler hasn't been touched for our test, so we can safely remove it.
  [currentThreadDict removeObjectForKey:NSAssertionHandlerKey];
  [handler release];
}

static void SenTestCase_performTest(id self, SEL sel, id arg1)
{
  SEL originalSelector = @selector(__SenTestCase_performTest:);
  XCPerformTestWithSuppressedExpectedAssertionFailures(self, originalSelector, arg1);
}

static void XCTestCase_performTest(id self, SEL sel, id arg1)
{
  SEL originalSelector = @selector(__XCTestCase_performTest:);
  XCPerformTestWithSuppressedExpectedAssertionFailures(self, originalSelector, arg1);
}

#pragma mark - _enableSymbolication
static BOOL XCTestCase__enableSymbolication(id self, SEL sel)
{
  return NO;
}

#pragma mark - Test Scope

static NSString * SenTestProbe_testScope(Class cls, SEL cmd)
{
  return __testScope;
}

static void UpdateTestScope()
{
  static NSString * const testListFileKey = @"OTEST_TESTLIST_FILE";
  static NSString * const testingFrameworkFilterTestArgsKeyKey = @"OTEST_FILTER_TEST_ARGS_KEY";

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *testListFilePath = [defaults objectForKey:testListFileKey];
  NSString *testingFrameworkFilterTestArgsKey = [defaults objectForKey:testingFrameworkFilterTestArgsKeyKey];
  if (!testListFilePath && !testingFrameworkFilterTestArgsKey) {
    return;
  }
  NSCAssert(testListFilePath, @"Path to file with list of tests should be specified");
  NSCAssert(testingFrameworkFilterTestArgsKey, @"Testing framework filter test args key should be specified");

  NSError *readError = nil;
  NSString *testList = [NSString stringWithContentsOfFile:testListFilePath encoding:NSUTF8StringEncoding error:&readError];
  NSCAssert(testList, @"Failed to read file at path %@ with error %@", testListFilePath, readError);
  [defaults setValue:testList forKey:testingFrameworkFilterTestArgsKey];

  __testScope = [testList retain];
}

#pragma mark - Interposes
/*
 *  We need to close opened fds so all pipe readers are notified and unblocked.
 *  The not obvious and weird part is that we need to print "\n" before closing.
 *  For some reason `select()`, `poll()` and `dispatch_io_read()` will be stuck
 *  if a test calls `exit()` or `abort()`. The found workaround was to print
 *  anithing to a pipe before closing it. Simply closing a pipe doesn't send EOF
 *  to the pipe reader. Printing "\n" should be safe because reader is skipping
 *  empty lines.
 */
static void PrintNewlineAndCloseFDs()
{
  if (__stdout == NULL) {
    return;
  }
  fprintf(__stdout, "\n");
  fclose(__stdout);
  __stdout = NULL;
}

#pragma mark - Entry

static const char *DyldImageStateChangeHandler(enum dyld_image_states state,
                                               uint32_t infoCount,
                                               const struct dyld_image_info info[])
{
  for (uint32_t i = 0; i < infoCount; i++) {
    // Sometimes the image path will be something like...
    //   '.../SenTestingKit.framework/SenTestingKit'
    // Other times it could be...
    //   '.../SenTestingKit.framework/Versions/A/SenTestingKit'
    if (strstr(info[i].imageFilePath, "SenTestingKit.framework") != NULL) {
      // Since the 'SenTestLog' class now exists, we can swizzle it!
      XTSwizzleClassSelectorForFunction(NSClassFromString(@"SenTestLog"),
                                        @selector(testSuiteDidStart:),
                                        (IMP)SenTestLog_testSuiteDidStart);
      XTSwizzleClassSelectorForFunction(NSClassFromString(@"SenTestLog"),
                                        @selector(testSuiteDidStop:),
                                        (IMP)SenTestLog_testSuiteDidStop);
      XTSwizzleClassSelectorForFunction(NSClassFromString(@"SenTestLog"),
                                        @selector(testCaseDidStart:),
                                        (IMP)SenTestLog_testCaseDidStart);
      XTSwizzleClassSelectorForFunction(NSClassFromString(@"SenTestLog"),
                                        @selector(testCaseDidStop:),
                                        (IMP)SenTestLog_testCaseDidStop);
      XTSwizzleClassSelectorForFunction(NSClassFromString(@"SenTestLog"),
                                        @selector(testCaseDidFail:),
                                        (IMP)SenTestLog_testCaseDidFail);
      XTSwizzleSelectorForFunction(NSClassFromString(@"SenTestCase"),
                                   @selector(performTest:),
                                   (IMP)SenTestCase_performTest);
      if (__testScope) {
        XTSwizzleClassSelectorForFunction(NSClassFromString(@"SenTestProbe"),
                                          @selector(testScope),
                                          (IMP)SenTestProbe_testScope);
      }

      NSDictionary *frameworkInfo = FrameworkInfoForExtension(@"octest");
      ApplyDuplicateTestNameFix([frameworkInfo objectForKey:kTestingFrameworkTestProbeClassName],
                                [frameworkInfo objectForKey:kTestingFrameworkTestSuiteClassName]);
      XTApplySenTestClassEnumeratorFix();
      XTApplySenTestCaseInvokeTestFix();
      XTApplySenIsSuperclassOfClassPerformanceFix();
    } else if (strstr(info[i].imageFilePath, "XCTest.framework") != NULL) {
      // Since the 'XCTestLog' class now exists, we can swizzle it!
      XTSwizzleSelectorForFunction(NSClassFromString(@"XCTestLog"),
                                   @selector(testSuiteDidStart:),
                                   (IMP)XCTestLog_testSuiteDidStart);
      XTSwizzleSelectorForFunction(NSClassFromString(@"XCTestLog"),
                                   @selector(testSuiteDidStop:),
                                   (IMP)XCTestLog_testSuiteDidStop);
      XTSwizzleSelectorForFunction(NSClassFromString(@"XCTestLog"),
                                   @selector(testCaseDidStart:),
                                   (IMP)XCTestLog_testCaseDidStart);
      XTSwizzleSelectorForFunction(NSClassFromString(@"XCTestLog"),
                                   @selector(testCaseDidStop:),
                                   (IMP)XCTestLog_testCaseDidStop);
      XTSwizzleSelectorForFunction(NSClassFromString(@"XCTestLog"),
                                   @selector(testCaseDidFail:withDescription:inFile:atLine:),
                                   (IMP)XCTestLog_testCaseDidFail);
      XTSwizzleSelectorForFunction(NSClassFromString(@"XCTestCase"),
                                   @selector(performTest:),
                                   (IMP)XCTestCase_performTest);
      if ([NSClassFromString(@"XCTestCase") respondsToSelector:@selector(_enableSymbolication)]) {
        // Disable symbolication thing on xctest 7 because it sometimes takes forever.
        XTSwizzleClassSelectorForFunction(NSClassFromString(@"XCTestCase"),
                                          @selector(_enableSymbolication),
                                          (IMP)XCTestCase__enableSymbolication);
      }
      NSDictionary *frameworkInfo = FrameworkInfoForExtension(@"xctest");
      ApplyDuplicateTestNameFix([frameworkInfo objectForKey:kTestingFrameworkTestProbeClassName],
                                [frameworkInfo objectForKey:kTestingFrameworkTestSuiteClassName]);
    }
  }

  return NULL;
}

void handle_signal(int signal)
{
  PrintNewlineAndCloseFDs();
}

__attribute__((constructor)) static void EntryPoint()
{
  const char *stdoutFileKey = "OTEST_SHIM_STDOUT_FILE";
  if (getenv(stdoutFileKey)) {
    __stdout = fopen(getenv(stdoutFileKey), "w");
  } else {
    int stdoutHandle = dup(STDOUT_FILENO);
    __stdout = fdopen(stdoutHandle, "w");
  }

  const char *stderrFileKey = "OTEST_SHIM_STDERR_FILE";
  if (getenv(stderrFileKey)) {
    __stderr = fopen(getenv(stderrFileKey), "w");
  } else {
    int stderrHandle = dup(STDERR_FILENO);
    __stderr = fdopen(stderrHandle, "w");
  }

  UpdateTestScope();

  struct sigaction sa_abort;
  sa_abort.sa_handler = &handle_signal;
  sigaction(SIGABRT, &sa_abort, NULL);

  // We need to swizzle SenTestLog (part of SenTestingKit), but the test bundle
  // which links SenTestingKit hasn't been loaded yet.  Let's register to get
  // notified when libraries are initialized and we'll watch for SenTestingKit.
  dyld_register_image_state_change_handler(dyld_image_state_initialized,
                                           NO,
                                           DyldImageStateChangeHandler);

  // Unset so we don't cascade into any other process that might be spawned.
  unsetenv("DYLD_INSERT_LIBRARIES");
}

__attribute__((destructor)) static void ExitPoint()
{
  PrintNewlineAndCloseFDs();
}
