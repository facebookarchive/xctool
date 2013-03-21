
#import "TestUtil.h"
#import "XcodeSubjectInfo.h"
#import "Fakes.h"
#import "Options.h"

@implementation TestUtil

//+ (Action *)actionWithArguments:(NSArray *)arguments
//{
//  Action *action = [[Action alloc] init];
//  NSString *errorMessage = nil;
//  NSUInteger consumed = [action consumeArguments:[NSMutableArray arrayWithArray:arguments] errorMessage:&errorMessage];
//  assertThat(errorMessage, equalTo(nil));
//  assertThatInteger(consumed, equalToInteger(arguments.count));
//  return action;
//}
//
//+ (Action *)validatedActionWithArguments:(NSArray *)arguments
//{
//  Action *action = [self actionWithArguments:arguments];
//  NSString *errorMessage = nil;
//  BOOL valid = [action validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease] options:nil];
//  assertThatBool(valid, equalToBool(YES));
//  return action;
//}
//
//+ (void)assertThatValidationWithArgumentList:(NSArray *)argumentList
//                            failsWithMessage:(NSString *)message
//{
//  Action *action = [self actionWithArguments:argumentList];
//  NSString *errorMessage = nil;
//  BOOL valid = [action validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease] options:nil];
//  assertThatBool(valid, equalToBool(NO));
//  assertThat(errorMessage, equalTo(message));
//}
//
//+ (void)assertThatValidationPassesWithArgumentList:(NSArray *)argumentList
//{
//  Action *action = [self actionWithArguments:argumentList];
//  NSString *errorMessage = nil;
//  BOOL valid = [action validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease] options:nil];
//  assertThatBool(valid, equalToBool(YES));
//}

+ (Options *)optionsFromArgumentList:(NSArray *)argumentList
{
  Options *options = [[[Options alloc] init] autorelease];
  NSString *errorMessage = nil;
  //  - (NSUInteger)consumeArguments:(NSMutableArray *)arguments errorMessage:(NSString **)errorMessage;
  
  [options consumeArguments:[NSMutableArray arrayWithArray:argumentList] errorMessage:&errorMessage];
//  BOOL parsed = [options parseOptionsFromArgumentList:argumentList errorMessage:&errorMessage];
  
  if (errorMessage != nil) {
    [NSException raise:NSGenericException format:@"Failed to parse options: %@", errorMessage];
  }

  return options;
}

+ (Options *)validatedOptionsFromArgumentList:(NSArray *)argumentList
{
  Options *options = [self optionsFromArgumentList:argumentList];
  NSString *errorMessage = nil;
  
  //[options consumeArguments:[NSMutableArray arrayWithArray:argumentList] errorMessage:&errorMessage];
  
  BOOL valid = [options validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease] options:options];
  //  BOOL valid = [options validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease]];
  
  if (!valid) {
    [NSException raise:NSGenericException format:@"Options are invalid: %@", errorMessage];
  }

  return options;
}

//+ (void)assertThatOptionsParseArgumentList:(NSArray *)argumentList failsWithMessage:(NSString *)message
//{
//  Options *options = [[[Options alloc] init] autorelease];
//  NSString *errorMessage = nil;
//  BOOL parsed = [options parseOptionsFromArgumentList:argumentList errorMessage:&errorMessage];
//  assertThatBool(parsed, equalToBool(NO));
//  assertThat(errorMessage, equalTo(message));
//}
//
+ (void)assertThatOptionsValidationWithArgumentList:(NSArray *)argumentList failsWithMessage:(NSString *)message
{
  Options *options = [self optionsFromArgumentList:argumentList];
  NSString *errorMessage = nil;
  //  BOOL valid = [options validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease]];
  BOOL valid = [options validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease] options:options];
  
  if (valid) {
    [NSException raise:NSGenericException format:@"Expected validation to failed, but passed."];
  } else if (!valid && ![message isEqualToString:errorMessage]) {
    [NSException raise:NSGenericException format:@"Expected validation to fail with message '%@' but instead failed with '%@'", message, errorMessage];
  }
}
//
//+ (void)assertThatOptionsValidationPassesWithArgumentList:(NSArray *)argumentList
//{
//  Options *options = [self optionsFromArgumentList:argumentList];
//  NSString *errorMessage = nil;
//  BOOL valid = [options validateOptions:&errorMessage xcodeSubjectInfo:[[[XcodeSubjectInfo alloc] init] autorelease]];
//  assertThatBool(valid, equalToBool(YES));
//}

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

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus
                    standardOutput:(NSString *)standardOutput
                     standardError:(NSString *)standardError {
  FakeTask *fakeTask = [[[FakeTask alloc] init] autorelease];
  
  fakeTask.onLaunchBlock = ^{
    // pretend that launch closes standardOutput / standardError pipes
    NSTask *task = fakeTask;
    
    NSFileHandle *(^fileHandleForWriting)(id) = ^(id pipeOrFileHandle) {
      if ([pipeOrFileHandle isKindOfClass:[NSPipe class]]) {
        return [pipeOrFileHandle fileHandleForWriting];
      } else {
        return (NSFileHandle *)pipeOrFileHandle;
      }
    };
    
    if (standardOutput) {
      [fileHandleForWriting([task standardOutput]) writeData:[standardOutput dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    if (standardError) {
      [fileHandleForWriting([task standardOutput]) writeData:[standardError dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [fileHandleForWriting([task standardOutput]) closeFile];
    [fileHandleForWriting([task standardError]) closeFile];
  };
  
  fakeTask.terminationStatus = exitStatus;
  
  return fakeTask;
}

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus {
  return [self fakeTaskWithExitStatus:exitStatus standardOutput:nil standardError:nil];
}

+ (NSTask *)fakeTask {
  return [self fakeTaskWithExitStatus:0 standardOutput:nil standardError:nil];
}

@end
