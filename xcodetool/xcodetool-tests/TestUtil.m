
#import "TestUtil.h"

#import "FakeTask.h"
#import "Options.h"
#import "XcodeSubjectInfo.h"

@implementation TestUtil

+ (Options *)optionsFromArgumentList:(NSArray *)argumentList
{
  Options *options = [[[Options alloc] init] autorelease];
  NSString *errorMessage = nil;
  [options consumeArguments:[NSMutableArray arrayWithArray:argumentList] errorMessage:&errorMessage];

  if (errorMessage != nil) {
    [NSException raise:NSGenericException format:@"Failed to parse options: %@", errorMessage];
  }

  return options;
}

+ (Options *)validatedOptionsFromArgumentList:(NSArray *)argumentList
{
  Options *options = [self optionsFromArgumentList:argumentList];
  NSString *errorMessage = nil;
  BOOL valid = [options validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease] options:options];

  if (!valid) {
    [NSException raise:NSGenericException format:@"Options are invalid: %@", errorMessage];
  }

  return options;
}

+ (void)assertThatOptionsValidateWithArgumentList:(NSArray *)argumentList
{
  Options *options = [self optionsFromArgumentList:argumentList];
  NSString *errorMessage = nil;

  BOOL valid = [options validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease] options:options];

  if (!valid) {
    [NSException raise:NSGenericException format:@"Expected validation to pass but failed with '%@'", errorMessage];
  }
}

+ (void)assertThatOptionsValidateWithArgumentList:(NSArray *)argumentList failsWithMessage:(NSString *)message
{
  Options *options = [self optionsFromArgumentList:argumentList];
  NSString *errorMessage = nil;

  BOOL valid = [options validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease] options:options];

  if (valid) {
    [NSException raise:NSGenericException format:@"Expected validation to failed, but passed."];
  } else if (!valid && ![message isEqualToString:errorMessage]) {
    [NSException raise:NSGenericException format:@"Expected validation to fail with message '%@' but instead failed with '%@'", message, errorMessage];
  }
}

+ (NSDictionary *)runWithFakeStreams:(XcodeTool *)tool
{
  __block NSString *standardOutput = nil;
  __block NSString *standardError = nil;

  NSPipe *standardOutputPipe = [NSPipe pipe];
  NSFileHandle *standardOutputReadHandle = [standardOutputPipe fileHandleForReading];
  NSFileHandle *standardOutputWriteHandle = [standardOutputPipe fileHandleForWriting];

  NSPipe *standardErrorPipe = [NSPipe pipe];
  NSFileHandle *standardErrorReadHandle = [standardErrorPipe fileHandleForReading];
  NSFileHandle *standardErrorWriteHandle = [standardErrorPipe fileHandleForWriting];

  void (^completionBlock)(NSNotification *) = ^(NSNotification *notification){
    NSData *data = notification.userInfo[NSFileHandleNotificationDataItem];
    NSString *str = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

    if (notification.object == standardOutputReadHandle) {
      standardOutput = str;
    } else if (notification.object == standardErrorReadHandle) {
      standardError = str;
    }

    CFRunLoopStop(CFRunLoopGetCurrent());
  };

  id standardOutputObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleReadToEndOfFileCompletionNotification
                                                                                object:standardOutputReadHandle
                                                                                 queue:nil
                                                                            usingBlock:completionBlock];
  [standardOutputReadHandle readToEndOfFileInBackgroundAndNotify];
  id standardErrorObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleReadToEndOfFileCompletionNotification
                                                                               object:standardErrorReadHandle
                                                                                queue:nil
                                                                           usingBlock:completionBlock];
  [standardErrorReadHandle readToEndOfFileInBackgroundAndNotify];

  tool.standardOutput = standardOutputWriteHandle;
  tool.standardError = standardErrorWriteHandle;

  [tool run];

  [standardOutputWriteHandle closeFile];
  [standardErrorWriteHandle closeFile];

  // Run until we've seen end-of-file for both streams.
  while (standardOutput == nil || standardError == nil) {
    CFRunLoopRun();
  }

  [[NSNotificationCenter defaultCenter] removeObserver:standardOutputObserver];
  [[NSNotificationCenter defaultCenter] removeObserver:standardErrorObserver];

  return @{@"stdout" : standardOutput, @"stderr" : standardError};
}

@end
