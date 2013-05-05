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

#import "../../xctool/xctool/Reporter.h"

#import "dyld-interposing.h"
#import "dyld_priv.h"

static int __stdoutHandle;
static FILE *__stdout;
static int __stderrHandle;
static FILE *__stderr;

static BOOL __testIsRunning = NO;
static NSException *__testException = nil;
static NSMutableString *__testOutput = nil;

static dispatch_queue_t __eventQueue = {0};

static NSArray *CreateParseTestName(NSString *fullTestName)
{
  id className = [NSNull null];
  id methodName = [NSNull null];
  if (fullTestName && [fullTestName length] > 6) {
    NSRegularExpression *testNameRegex =
      [NSRegularExpression regularExpressionWithPattern:@"^-\\[(\\w+) (\\w+)\\]$"
                                                options:0
                                                  error:nil];
    NSTextCheckingResult *match =
      [testNameRegex firstMatchInString:fullTestName
                                options:0
                                  range:NSMakeRange(0, [fullTestName length])];
    if (match && [match numberOfRanges] == 3) {
      NSRange groupRange = [match rangeAtIndex:1];
      if (groupRange.location != NSNotFound) {
        className = [fullTestName substringWithRange:groupRange];
      }
      groupRange = [match rangeAtIndex:2];
      if (groupRange.location != NSNotFound) {
        methodName = [fullTestName substringWithRange:groupRange];
      }
    }
  }
  return [[NSArray alloc] initWithObjects:className, methodName, nil];
}

static void SwizzleClassSelectorForFunction(Class cls, SEL sel, IMP newImp)
{
  Class clscls = object_getClass((id)cls);
  Method originalMethod = class_getClassMethod(cls, sel);

  NSString *selectorName = [NSString stringWithFormat:@"__%s_%s", class_getName(cls), sel_getName(sel)];
  SEL newSelector = sel_registerName([selectorName cStringUsingEncoding:[NSString defaultCStringEncoding]]);

  class_addMethod(clscls, newSelector, newImp, method_getTypeEncoding(originalMethod));
  Method replacedMethod = class_getClassMethod(cls, newSelector);
  method_exchangeImplementations(originalMethod, replacedMethod);
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

static void SenTestLog_testSuiteDidStart(id self, SEL sel, NSNotification *notification)
{
  dispatch_sync(__eventQueue, ^{
    SenTestRun *run = [notification run];
    PrintJSON(@{
              @"event" : kReporter_Events_BeginTestSuite,
              kReporter_BeginTestSuite_SuiteKey : [[run test] description],
              });
  });
}

static void SenTestLog_testSuiteDidStop(id self, SEL sel, NSNotification *notification)
{
  dispatch_sync(__eventQueue, ^{
    SenTestRun *run = [notification run];
    PrintJSON(@{
              @"event" : kReporter_Events_EndTestSuite,
              kReporter_EndTestSuite_SuiteKey : [[run test] description],
              kReporter_EndTestSuite_TestCaseCountKey : @([run testCaseCount]),
              kReporter_EndTestSuite_TotalFailureCountKey : @([run totalFailureCount]),
              kReporter_EndTestSuite_UnexpectedExceptionCountKey : @([run unexpectedExceptionCount]),
              kReporter_EndTestSuite_TestDurationKey: @([run testDuration]),
              kReporter_EndTestSuite_TotalDurationKey : @([run totalDuration]),
              });
  });
}

static void SenTestLog_testCaseDidStart(id self, SEL sel, NSNotification *notification)
{
  dispatch_sync(__eventQueue, ^{
    SenTestRun *run = [notification run];
    NSString *fullTestName = [[run test] description];
    NSArray *classAndMethodNames = CreateParseTestName(fullTestName);
    PrintJSON(@{
              @"event" : kReporter_Events_BeginTest,
              kReporter_BeginTest_TestKey : [[run test] description],
              kReporter_BeginTest_ClassNameKey : [classAndMethodNames objectAtIndex:0],
              kReporter_BeginTest_MethodNameKey : [classAndMethodNames objectAtIndex:1],
              });

    [classAndMethodNames release];
    classAndMethodNames = nil;
    [__testException release];
    __testException = nil;
    __testIsRunning = YES;
    __testOutput = [[NSMutableString string] retain];
  });
}

static void SenTestLog_testCaseDidStop(id self, SEL sel, NSNotification *notification)
{
  dispatch_sync(__eventQueue, ^{
    SenTestRun *run = [notification run];
    NSString *fullTestName = [[run test] description];
    NSArray *classAndMethodNames = CreateParseTestName(fullTestName);
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithDictionary:@{
                                 @"event" : kReporter_Events_EndTest,
                                 kReporter_EndTest_TestKey : [[run test] description],
                                 kReporter_EndTest_ClassNameKey : [classAndMethodNames objectAtIndex:0],
                                 kReporter_EndTest_MethodNameKey : [classAndMethodNames objectAtIndex:1],
                                 kReporter_EndTest_SucceededKey : [run hasSucceeded] ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO],
                                 kReporter_EndTest_TotalDurationKey : @([run totalDuration]),
                                 kReporter_EndTest_OutputKey : __testOutput,
                                 }];

    if (__testException != nil) {
      [json setObject:@{
       kReporter_EndTest_Exception_FilePathInProjectKey : [__testException filePathInProject],
       kReporter_EndTest_Exception_LineNumberKey : [__testException lineNumber],
       kReporter_EndTest_Exception_ReasonKey : [__testException reason],
       kReporter_EndTest_Exception_NameKey : [__testException name],
       }
               forKey:kReporter_EndTest_ExceptionKey];
    }

    PrintJSON(json);

    [classAndMethodNames release];
    classAndMethodNames = nil;
    __testIsRunning = NO;
    [__testOutput release];
    __testOutput = nil;
  });
}

static void SenTestLog_testCaseDidFail(id self, SEL sel, NSNotification *notification)
{
  dispatch_sync(__eventQueue, ^{
    NSException *exception = [notification exception];
    if (__testException != exception) {
      [__testException release];
      __testException = [exception retain];
    }
  });
}

static void SaveExitMode(NSDictionary *exitMode)
{
  NSDictionary *env = [[NSProcessInfo processInfo] environment];
  NSString *saveExitModeTo = [env objectForKey:@"SAVE_EXIT_MODE_TO"];

  if (saveExitModeTo) {
    assert([exitMode writeToFile:saveExitModeTo atomically:YES] == YES);
  }
}

static void __exit(int status)
{
  SaveExitMode(@{@"via" : @"exit", @"status" : @(status) });
  exit(status);
}
DYLD_INTERPOSE(__exit, exit);

static void __abort()
{
  SaveExitMode(@{@"via" : @"abort"});
  abort();
}
DYLD_INTERPOSE(__abort, abort);

// From /usr/lib/system/libsystem_kernel.dylib - output from printf/fprintf/fwrite will flow to
// __write_nonancel just before it does the system call.
ssize_t __write_nocancel(int fildes, const void *buf, size_t nbyte);
static ssize_t ___write_nocancel(int fildes, const void *buf, size_t nbyte)
{
  if (fildes == STDOUT_FILENO || fildes == STDERR_FILENO) {
    dispatch_sync(__eventQueue, ^{
      if (__testIsRunning && nbyte > 0) {
        NSString *output = [[NSString alloc] initWithBytes:buf length:nbyte encoding:NSUTF8StringEncoding];
        PrintJSON(@{@"event": kReporter_Events_TestOuput, kReporter_TestOutput_OutputKey: output});
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
    dispatch_sync(__eventQueue, ^{
      if (__testIsRunning && nbyte > 0) {
        NSString *output = [[NSString alloc] initWithBytes:buf length:nbyte encoding:NSUTF8StringEncoding];
        PrintJSON(@{@"event": kReporter_Events_TestOuput, kReporter_TestOutput_OutputKey: output});
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
    dispatch_sync(__eventQueue, ^{
      if (__testIsRunning && iovcnt > 0) {
        NSString *buffer = CreateStringFromIOV(iov, iovcnt);
        PrintJSON(@{@"event": kReporter_Events_TestOuput, kReporter_TestOutput_OutputKey: buffer});
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
    dispatch_sync(__eventQueue, ^{
      if (__testIsRunning && iovcnt > 0) {
        NSString *buffer = CreateStringFromIOV(iov, iovcnt);
        PrintJSON(@{@"event": kReporter_Events_TestOuput, kReporter_TestOutput_OutputKey: buffer});
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
      SwizzleClassSelectorForFunction(NSClassFromString(@"SenTestLog"),
                                      @selector(testSuiteDidStart:),
                                      (IMP)SenTestLog_testSuiteDidStart);
      SwizzleClassSelectorForFunction(NSClassFromString(@"SenTestLog"),
                                      @selector(testSuiteDidStop:),
                                      (IMP)SenTestLog_testSuiteDidStop);
      SwizzleClassSelectorForFunction(NSClassFromString(@"SenTestLog"),
                                      @selector(testCaseDidStart:),
                                      (IMP)SenTestLog_testCaseDidStart);
      SwizzleClassSelectorForFunction(NSClassFromString(@"SenTestLog"),
                                      @selector(testCaseDidStop:),
                                      (IMP)SenTestLog_testCaseDidStop);
      SwizzleClassSelectorForFunction(NSClassFromString(@"SenTestLog"),
                                      @selector(testCaseDidFail:),
                                      (IMP)SenTestLog_testCaseDidFail);
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
  __eventQueue = dispatch_queue_create("xctool.events", DISPATCH_QUEUE_SERIAL);

  // We need to swizzle SenTestLog (part of SenTestingKit), but the test bundle
  // which links SenTestingKit hasn't been loaded yet.  Let's register to get
  // notified when libraries are initialized and we'll watch for SenTestingKit.
  dyld_register_image_state_change_handler(dyld_image_state_initialized,
                                           NO,
                                           DyldImageStateChangeHandler);

  // Unset so we don't cascade into any other process that might be spawned.
  unsetenv("DYLD_INSERT_LIBRARIES");
}

