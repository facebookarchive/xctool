
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <SenTestingKit/SenTestingKit.h>
#import <sys/uio.h>
#import "dyld-interposing.h"
#import "PJSONKit.h"

static int __stdoutHandle;
static FILE *__stdout;
static int __stderrHandle;
static FILE *__stderr;

static BOOL __testIsRunning = NO;
static NSException *__testException = nil;
static NSMutableString *__testOutput = nil;

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

void PrintJSON(id JSONObject)
{
  NSError *error = nil;
  NSData *data = [JSONObject XT_JSONDataWithOptions:XT_JKSerializeOptionNone error:&error];
  
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
  SenTestRun *run = [notification run];
  PrintJSON(@{
            @"event" : @"begin-test-suite",
            @"suite" : [[run test] description],
            });
}

static void SenTestLog_testSuiteDidStop(id self, SEL sel, NSNotification *notification)
{
  SenTestRun *run = [notification run];
  PrintJSON(@{
            @"event" : @"end-test-suite",
            @"suite" : [[run test] description],
            @"testCaseCount" : @([run testCaseCount]),
            @"totalFailureCount" : @([run totalFailureCount]),
            @"unexpectedExceptionCount" : @([run unexpectedExceptionCount]),
            @"testDuration" : @([run testDuration]),
            @"totalDuration" : @([run totalDuration]),
            });
}

static void SenTestLog_testCaseDidStart(id self, SEL sel, NSNotification *notification)
{
  SenTestRun *run = [notification run];
  PrintJSON(@{
            @"event" : @"begin-test",
            @"test" : [[run test] description],
            });
  
  [__testException release];
  __testException = nil;
  __testIsRunning = YES;
  __testOutput = [[NSMutableString string] retain];
}

static void SenTestLog_testCaseDidStop(id self, SEL sel, NSNotification *notification)
{
  SenTestRun *run = [notification run];
  NSMutableDictionary *json = [NSMutableDictionary dictionaryWithDictionary:@{
                               @"event" : @"end-test",
                               @"test" : [[run test] description],
                               @"succeeded" : [run hasSucceeded] ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO],
                               @"totalDuration" : @([run totalDuration]),
                               @"output" : __testOutput,
                               }];
  
  if (__testException != nil) {
    [json setObject:@{
     @"filePathInProject" : [__testException filePathInProject],
     @"lineNumber" : [__testException lineNumber],
     @"reason" : [__testException reason],
     }
             forKey:@"exception"];
  }
  
  PrintJSON(json);
  
  __testIsRunning = NO;
  [__testOutput release];
  __testOutput = nil;
}

static void SenTestLog_testCaseDidFail(id self, SEL sel, NSNotification *notification)
{
  NSException *exception = [notification exception];
  if (__testException != exception) {
    [__testException release];
    __testException = [exception retain];
  }
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
    if (__testIsRunning && nbyte > 0) {
      NSString *output = [[NSString alloc] initWithBytes:buf length:nbyte encoding:NSUTF8StringEncoding];
      PrintJSON(@{@"event": @"test-output", @"output": output});
      [__testOutput appendString:output];
      [output release];
    }
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
    if (__testIsRunning && nbyte > 0) {
      NSString *output = [[NSString alloc] initWithBytes:buf length:nbyte encoding:NSUTF8StringEncoding];
      PrintJSON(@{@"event": @"test-output", @"output": output});
      [__testOutput appendString:output];
      [output release];
    }
    return nbyte;
  } else {
    return write(fildes, buf, nbyte);
  }
}
DYLD_INTERPOSE(__write, write);

// Output from NSLog flows through writev
static ssize_t __writev(int fildes, const struct iovec *iov, int iovcnt)
{
  if (fildes == STDOUT_FILENO || fildes == STDERR_FILENO) {
    if (__testIsRunning && iovcnt > 0) {
      NSMutableString *buffer = [[NSMutableString alloc] initWithCapacity:1024];

      for (int i = 0; i < iovcnt; i++) {
        NSString *str = [[NSString alloc] initWithBytes:iov[i].iov_base length:iov[i].iov_len encoding:NSUTF8StringEncoding];
        [buffer appendString:str];
        [str release];
      }
      
      PrintJSON(@{@"event": @"test-output", @"output": buffer});
      [__testOutput appendString:buffer];
      
      [buffer release];
    }
    return iovcnt;
  } else {
    return writev(fildes, iov, iovcnt);
  }
}
DYLD_INTERPOSE(__writev, writev);

__attribute__((constructor)) static void EntryPoint()
{
  __stdoutHandle = dup(STDOUT_FILENO);
  __stdout = fdopen(__stdoutHandle, "w");
  __stderrHandle = dup(STDERR_FILENO);
  __stderr = fdopen(__stderrHandle, "w");
  
  void (^doSwizzleBlock)() = [^{
    SwizzleClassSelectorForFunction(NSClassFromString(@"SenTestLog"), @selector(testSuiteDidStart:), (IMP)SenTestLog_testSuiteDidStart);
    SwizzleClassSelectorForFunction(NSClassFromString(@"SenTestLog"), @selector(testSuiteDidStop:), (IMP)SenTestLog_testSuiteDidStop);
    SwizzleClassSelectorForFunction(NSClassFromString(@"SenTestLog"), @selector(testCaseDidStart:), (IMP)SenTestLog_testCaseDidStart);
    SwizzleClassSelectorForFunction(NSClassFromString(@"SenTestLog"), @selector(testCaseDidStop:), (IMP)SenTestLog_testCaseDidStop);
    SwizzleClassSelectorForFunction(NSClassFromString(@"SenTestLog"), @selector(testCaseDidFail:), (IMP)SenTestLog_testCaseDidFail);
  } copy];
  
  if ([[[NSProcessInfo processInfo] processName] isEqualToString:@"otest"]) {
    // This is a logic test, and the test bundle is loaded directly by otest.
    __block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSBundleDidLoadNotification object:nil queue:nil usingBlock:[^(NSNotification *notification) {
      if (NSClassFromString(@"SenTestObserver")) {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
        doSwizzleBlock();
      }
    } copy]];
  } else {
    // This must be an application test and we're running the simulator.  The test bundle gets
    // started by adding an operation to the run loop.  So, before that happens, let's add our own
    // operation to do the swizzling as soon as the run loop is going.
    [doSwizzleBlock performSelector:@selector(invoke) withObject:nil afterDelay:0.0];
  }  
  
  // Unset so we don't cascade into other process that get spawned from xcodebuild.
  unsetenv("DYLD_INSERT_LIBRARIES");
}