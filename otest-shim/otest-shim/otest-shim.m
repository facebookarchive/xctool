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

#import <mach-o/dyld.h>
#import <mach-o/dyld_images.h>

#import <objc/runtime.h>

#import <sys/uio.h>

#import "DuplicateTestNameFix.h"
#import "dyld-interposing.h"
#import "dyld_priv.h"
#import "EventGenerator.h"
#import "NSInvocationInSetFix.h"
#import "ParseTestName.h"
#import "ReporterEvents.h"
#import "SenIsSuperclassOfClassPerformanceFix.h"
#import "SenTestCaseInvokeTestFix.h"
#import "SenTestClassEnumeratorFix.h"
#import "Swizzle.h"
#import "TestingFramework.h"
#import "XCTest.h"

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

static BOOL __testIsRunning = NO;
static NSMutableArray *__testExceptions = nil;
static NSMutableData *__testOutput = nil;
static int __testSuiteDepth = 0;

static BOOL __testBundleHasStartedRunning = NO;

static NSString *__testScope = nil;

/**
 We don't want to turn this on until our initializer runs.  Otherwise, dylibs
 that are loaded earlier (like libSystem) will call into our interposed
 functions, but we're not ready for that yet.
 */
static BOOL __enableWriteInterception = NO;

static dispatch_queue_t EventQueue()
{
  static dispatch_queue_t eventQueue = {0};
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    // We'll serialize all events through this queue.  There are a couple of race
    // conditions that can happen when tests spawn threads that try to write to
    // stdout or stderr.
    //
    // 1) Multiple threads can be writing at the same time and their output can
    // stomp on each other.  e.g. the JSON can get corrupted like this...
    // {"event":"test-out{event:"test-output","output":"blah"}put","output":"blah"}
    //
    // 2) Threads can generate "test-output" events outside of a running tests.
    // e.g. a test begins (begin-test), a thread is spawned and it keeps writing
    // to stdout, the test case ends (end-test), but the thread keeps writing to
    // stdout and generating 'test-output' events.  We have a global variable
    // '__testIsRunning' that we can check to see if we're in the middle of a
    // running test, but there can be race conditions with multiple threads.
    eventQueue = dispatch_queue_create("xctool.events", DISPATCH_QUEUE_SERIAL);
  });

  return eventQueue;
}

// This function will strip ANSI escape codes from a string passed to it
//
// Used to clean the output from certain tests which contain ANSI escape codes, and create problems for XML and JSON
// representations of output data.
// The regex here will identify all screen oriented ANSI escape codes, but will not identify Keyboard String codes.
// Since Keyboard String codes make no sense in this context, the added complexity of having a regex try to identify
// those codes as well was not necessary
NSString *StripAnsi(NSString *inputString)
{
  static dispatch_once_t onceToken;
  static NSRegularExpression *regex;
  dispatch_once(&onceToken, ^{
    NSString *pattern =
      @"\\\e\\[("          // Esc[
      @"\\d+;\\d+[Hf]|"    // Esc[Line;ColumnH | Esc[Line;Columnf
      @"\\d+[ABCD]|"       // Esc[ValueA | Esc[ValueB | Esc[ValueC | Esc[ValueD
      @"([suKm]|2J)|"      // Esc[s | Esc[u | Esc[2J | Esc[K | Esc[m
      @"\\=\\d+[hI]|"      // Esc[=Valueh | Esc[=ValueI
      @"(\\d+;)*(\\d+)m)"; // Esc[Value;...;Valuem
    regex = [[NSRegularExpression alloc] initWithPattern:pattern
                                                 options:0
                                                   error:nil];
  });

  if (inputString == nil) {
    return @"";
  }

  NSString *outputString = [regex stringByReplacingMatchesInString:inputString
                                                           options:0
                                                             range:NSMakeRange(0, [inputString length])
                                                      withTemplate:@""];
  return outputString;
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
  __testBundleHasStartedRunning = YES;

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
    __testIsRunning = YES;
    __testOutput = [[NSMutableData dataWithCapacity:0] retain];
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

    NSString *testOutput = [[NSString alloc] initWithData:__testOutput encoding:NSUTF8StringEncoding];

    // print all unprinted test output bytes in case `__testOutput` doesn't end with "\n"
    if (![testOutput hasSuffix:@"\n"]) {
      NSRange range = [testOutput rangeOfString:@"\n" options:NSBackwardsSearch];
      if (range.length == 0) {
        range.location = 0;
      }
      NSString *line = [testOutput substringFromIndex:NSMaxRange(range)];
      PrintJSON(EventDictionaryWithNameAndContent(
        kReporter_Events_TestOuput,
        @{kReporter_TestOutput_OutputKey: StripAnsi(line)}
      ));
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
        kReporter_EndTest_OutputKey : StripAnsi(testOutput),
        kReporter_EndTest_ExceptionsKey : retExceptions,
    });
    [retExceptions release];

    PrintJSON(json);

    __testIsRunning = NO;
    [__testOutput release];
    __testOutput = nil;
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

#pragma mark -

static void ProcessTestOutputWriteBytes(const void *buf, size_t nbyte)
{
  static NSData *newlineData = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    newlineData = [[NSData alloc] initWithBytes:"\n" length:1];
  });

  // search for the last "\n" w/o new buffer
  NSRange previousNewlineRange = [__testOutput rangeOfData:newlineData
                                                   options:NSDataSearchBackwards
                                                     range:NSMakeRange(0, __testOutput.length)];
  NSUInteger offset = previousNewlineRange.length != 0 ? NSMaxRange(previousNewlineRange) : 0;

  // append new bytes
  [__testOutput appendBytes:buf length:nbyte];

  // check if "\n" is in the buf
  NSRange newlineRange = [__testOutput rangeOfData:newlineData
                                           options:NSDataSearchBackwards
                                             range:NSMakeRange(offset, __testOutput.length - offset)];
  if (newlineRange.length == 0) {
    return;
  }

  NSData *lineData = [__testOutput subdataWithRange:NSMakeRange(offset, NSMaxRange(newlineRange) - offset)];
  NSString *line = [[NSString alloc] initWithData:lineData encoding:NSUTF8StringEncoding];
  PrintJSON(EventDictionaryWithNameAndContent(
    kReporter_Events_TestOuput,
    @{kReporter_TestOutput_OutputKey: StripAnsi(line)}
  ));
  [line release];
}

static void ProcessBeforeTestRunWriteBytes(const void *buf, size_t nbyte)
{
  NSString *output = [[NSString alloc] initWithBytes:buf length:nbyte encoding:NSUTF8StringEncoding];
  PrintJSON(EventDictionaryWithNameAndContent(kReporter_Events_OutputBeforeTestBundleStarts,
                                              @{kReporter_OutputBeforeTestBundleStarts_OutputKey: StripAnsi(output)}
                                              ));
  [output release];
}

// From /usr/lib/system/libsystem_kernel.dylib - output from printf/fprintf/fwrite will flow to
// __write_nonancel just before it does the system call.
ssize_t __write_nocancel(int fildes, const void *buf, size_t nbyte);
static ssize_t ___write_nocancel(int fildes, const void *buf, size_t nbyte)
{
  if (__enableWriteInterception && (fildes == STDOUT_FILENO || fildes == STDERR_FILENO)) {
    dispatch_sync(EventQueue(), ^{
      if (__testIsRunning && nbyte > 0) {
        ProcessTestOutputWriteBytes(buf, nbyte);
      } else if (!__testBundleHasStartedRunning && nbyte > 0) {
        ProcessBeforeTestRunWriteBytes(buf, nbyte);
      }
    });
    return nbyte;
  } else {
    return write(fildes, buf, nbyte);
  }
}
DYLD_INTERPOSE(___write_nocancel, __write_nocancel);

static ssize_t __write(int fildes, const void *buf, size_t nbyte);
static ssize_t __write(int fildes, const void *buf, size_t nbyte)
{
  if (__enableWriteInterception && (fildes == STDOUT_FILENO || fildes == STDERR_FILENO)) {
    dispatch_sync(EventQueue(), ^{
      if (__testIsRunning && nbyte > 0) {
        ProcessTestOutputWriteBytes(buf, nbyte);
      } else if (!__testBundleHasStartedRunning && nbyte > 0) {
        ProcessBeforeTestRunWriteBytes(buf, nbyte);
      }
    });
    return nbyte;
  } else {
    return write(fildes, buf, nbyte);
  }
}
DYLD_INTERPOSE(__write, write);

static NSData *CreateDataFromIOV(const struct iovec *iov, int iovcnt) {
  NSMutableData *buffer = [[NSMutableData alloc] initWithCapacity:0];

  for (int i = 0; i < iovcnt; i++) {
    [buffer appendBytes:iov[i].iov_base length:iov[i].iov_len];
  }

  NSMutableData *bufferWithoutNulls = [[NSMutableData alloc] initWithLength:buffer.length];

  NSUInteger offset = 0;
  uint8_t *bufferBytes = (uint8_t *)[buffer mutableBytes];
  uint8_t *bufferWithoutNullsBytes = (uint8_t *)[bufferWithoutNulls mutableBytes];

  for (NSUInteger i = 0; i < buffer.length; i++) {
    uint8_t byte = bufferBytes[i];
    if (byte != 0) {
      bufferWithoutNullsBytes[offset++] = byte;
    }
  }

  [bufferWithoutNulls setLength:offset];

  [buffer release];

  return bufferWithoutNulls;
}

// From /usr/lib/system/libsystem_kernel.dylib - output from writev$NOCANCEL$UNIX2003 will flow
// here.  'backtrace_symbols_fd' is one function that sends output this direction.
ssize_t __writev_nocancel(int fildes, const struct iovec *iov, int iovcnt);
static ssize_t ___writev_nocancel(int fildes, const struct iovec *iov, int iovcnt)
{
  if (__enableWriteInterception && (fildes == STDOUT_FILENO || fildes == STDERR_FILENO)) {
    dispatch_sync(EventQueue(), ^{
      if (__testIsRunning && iovcnt > 0) {
        NSData *data = CreateDataFromIOV(iov, iovcnt);
        ProcessTestOutputWriteBytes(data.bytes, data.length);
        [data release];
      } else if (!__testBundleHasStartedRunning && iovcnt > 0) {
        NSData *data = CreateDataFromIOV(iov, iovcnt);
        ProcessBeforeTestRunWriteBytes(data.bytes, data.length);
        [data release];
      }
    });
    return iovcnt;
  } else {
    return __writev_nocancel(fildes, iov, iovcnt);
  }
}
DYLD_INTERPOSE(___writev_nocancel, __writev_nocancel);

// Output from NSLog flows through writev
static ssize_t __writev(int fildes, const struct iovec *iov, int iovcnt)
{
  if (__enableWriteInterception && (fildes == STDOUT_FILENO || fildes == STDERR_FILENO)) {
    dispatch_sync(EventQueue(), ^{
      if (__testIsRunning && iovcnt > 0) {
        NSData *data = CreateDataFromIOV(iov, iovcnt);
        ProcessTestOutputWriteBytes(data.bytes, data.length);
        [data release];
      } else if (!__testBundleHasStartedRunning && iovcnt > 0) {
        NSData *data = CreateDataFromIOV(iov, iovcnt);
        ProcessBeforeTestRunWriteBytes(data.bytes, data.length);
        [data release];
      }
    });

    return iovcnt;
  } else {
    return writev(fildes, iov, iovcnt);
  }
}
DYLD_INTERPOSE(__writev, writev);

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
    }
    else if (strstr(info[i].imageFilePath, "XCTest.framework") != NULL) {
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
      NSDictionary *frameworkInfo = FrameworkInfoForExtension(@"xctest");
      ApplyDuplicateTestNameFix([frameworkInfo objectForKey:kTestingFrameworkTestProbeClassName],
                                [frameworkInfo objectForKey:kTestingFrameworkTestSuiteClassName]);
    }
  }

  return NULL;
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

  // We need to swizzle SenTestLog (part of SenTestingKit), but the test bundle
  // which links SenTestingKit hasn't been loaded yet.  Let's register to get
  // notified when libraries are initialized and we'll watch for SenTestingKit.
  dyld_register_image_state_change_handler(dyld_image_state_initialized,
                                           NO,
                                           DyldImageStateChangeHandler);

  // Unset so we don't cascade into any other process that might be spawned.
  unsetenv("DYLD_INSERT_LIBRARIES");

  __enableWriteInterception = YES;
}
