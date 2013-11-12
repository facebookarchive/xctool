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

#import <mach-o/dyld.h>
#import <mach-o/dyld_images.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <sys/uio.h>

#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>

#import "XCTest.h"

#import "DuplicateTestNameFix.h"
#import "EventGenerator.h"
#import "ParseTestName.h"
#import "ReporterEvents.h"
#import "Swizzle.h"
#import "TestingFramework.h"

#import "dyld-interposing.h"
#import "dyld_priv.h"

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

static int __stdoutHandle;
static FILE *__stdout;
static int __stderrHandle;
static FILE *__stderr;

static BOOL __testIsRunning = NO;
static NSMutableArray *__testExceptions = nil;
static NSMutableString *__testOutput = nil;
static int __testSuiteDepth = 0;

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
static NSString *StripAnsi(NSString *inputString)
{
  NSRegularExpression *regex =
    [NSRegularExpression regularExpressionWithPattern:@"\\e\\[(\\d;)??(\\d{1,2}[mHfABCDJhI])"
                                              options:0
                                                error:nil];
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
    __testOutput = [[NSMutableString string] retain];
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
    
    NSArray *retExceptions = [__testExceptions copy];
    NSDictionary *json = EventDictionaryWithNameAndContent(
      kReporter_Events_EndTest, @{
        kReporter_EndTest_TestKey : fullTestName,
        kReporter_EndTest_ClassNameKey : className,
        kReporter_EndTest_MethodNameKey : methodName,
        kReporter_EndTest_SucceededKey: @(succeeded),
        kReporter_EndTest_ResultKey : result,
        kReporter_EndTest_TotalDurationKey : totalDuration,
        kReporter_EndTest_OutputKey : StripAnsi(__testOutput),
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
  NSAssertionHandler *handler = [[XCToolAssertionHandler alloc] init];
  NSThread *currentThread = [NSThread currentThread];
  NSMutableDictionary *currentThreadDict = [currentThread threadDictionary];
  [currentThreadDict setObject:handler forKey:NSAssertionHandlerKey];

  // Call through original implementation
  objc_msgSend(self, origSel, arg1);

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

#pragma mark -

// From /usr/lib/system/libsystem_kernel.dylib - output from printf/fprintf/fwrite will flow to
// __write_nonancel just before it does the system call.
ssize_t __write_nocancel(int fildes, const void *buf, size_t nbyte);
static ssize_t ___write_nocancel(int fildes, const void *buf, size_t nbyte)
{
  if (fildes == STDOUT_FILENO || fildes == STDERR_FILENO) {
    dispatch_sync(EventQueue(), ^{
      if (__testIsRunning && nbyte > 0) {
        NSString *output = [[NSString alloc] initWithBytes:buf length:nbyte encoding:NSUTF8StringEncoding];
        PrintJSON(EventDictionaryWithNameAndContent(
          kReporter_Events_TestOuput,
          @{kReporter_TestOutput_OutputKey: StripAnsi(output)}
        ));
        [__testOutput appendString:output];
        [output release];
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
  if (fildes == STDOUT_FILENO || fildes == STDERR_FILENO) {
    dispatch_sync(EventQueue(), ^{
      if (__testIsRunning && nbyte > 0) {
        NSString *output = [[NSString alloc] initWithBytes:buf length:nbyte encoding:NSUTF8StringEncoding];
        PrintJSON(EventDictionaryWithNameAndContent(
          kReporter_Events_TestOuput,
          @{kReporter_TestOutput_OutputKey: StripAnsi(output)}
        ));
        [__testOutput appendString:output];
        [output release];
      }
    });
    return nbyte;
  } else {
    return write(fildes, buf, nbyte);
  }
}
DYLD_INTERPOSE(__write, write);

static NSString *CreateStringFromIOV(const struct iovec *iov, int iovcnt) {
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

  NSString *str = [[NSString alloc] initWithData:bufferWithoutNulls encoding:NSUTF8StringEncoding];

  [buffer release];
  [bufferWithoutNulls release];

  return str;
}

// From /usr/lib/system/libsystem_kernel.dylib - output from writev$NOCANCEL$UNIX2003 will flow
// here.  'backtrace_symbols_fd' is one function that sends output this direction.
ssize_t __writev_nocancel(int fildes, const struct iovec *iov, int iovcnt);
static ssize_t ___writev_nocancel(int fildes, const struct iovec *iov, int iovcnt)
{
  if (fildes == STDOUT_FILENO || fildes == STDERR_FILENO) {
    dispatch_sync(EventQueue(), ^{
      if (__testIsRunning && iovcnt > 0) {
        NSString *buffer = CreateStringFromIOV(iov, iovcnt);
        PrintJSON(EventDictionaryWithNameAndContent(
          kReporter_Events_TestOuput,
          @{kReporter_TestOutput_OutputKey: StripAnsi(buffer)}
        ));
        [__testOutput appendString:buffer];
        [buffer release];
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
  if (fildes == STDOUT_FILENO || fildes == STDERR_FILENO) {
    dispatch_sync(EventQueue(), ^{
      if (__testIsRunning && iovcnt > 0) {
        NSString *buffer = CreateStringFromIOV(iov, iovcnt);
        PrintJSON(EventDictionaryWithNameAndContent(
          kReporter_Events_TestOuput,
          @{kReporter_TestOutput_OutputKey: StripAnsi(buffer)}
        ));
        [__testOutput appendString:buffer];
        [buffer release];
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

      NSDictionary *frameworkInfo = FrameworkInfoForExtension(@"octest");
      ApplyDuplicateTestNameFix([frameworkInfo objectForKey:kTestingFrameworkTestProbeClassName]);
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
      ApplyDuplicateTestNameFix([frameworkInfo objectForKey:kTestingFrameworkTestProbeClassName]);
    }
  }

  return NULL;
}

__attribute__((constructor)) static void EntryPoint()
{
  __stdoutHandle = dup(STDOUT_FILENO);
  __stdout = fdopen(__stdoutHandle, "w");
  __stderrHandle = dup(STDERR_FILENO);
  __stderr = fdopen(__stderrHandle, "w");

  // We need to swizzle SenTestLog (part of SenTestingKit), but the test bundle
  // which links SenTestingKit hasn't been loaded yet.  Let's register to get
  // notified when libraries are initialized and we'll watch for SenTestingKit.
  dyld_register_image_state_change_handler(dyld_image_state_initialized,
                                           NO,
                                           DyldImageStateChangeHandler);

  // Unset so we don't cascade into any other process that might be spawned.
  unsetenv("DYLD_INSERT_LIBRARIES");
}

