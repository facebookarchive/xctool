// Copyright 2004-present Facebook. All Rights Reserved.


#import "TaskUtil.h"
#import "LineReader.h"

static NSMutableArray *__fakeTasks = nil;
static NSTask *(^__TaskInstanceBlock)(void) = nil;

NSTask *TaskInstance(void)
{
  if (__TaskInstanceBlock == nil) {
    return [[[NSTask alloc] init] autorelease];
  } else {
    return __TaskInstanceBlock();
  }
}

void SetTaskInstanceBlock(NSTask *(^taskInstanceBlock)())
{
  if (__TaskInstanceBlock != taskInstanceBlock) {
    [__TaskInstanceBlock release];
    __TaskInstanceBlock = [taskInstanceBlock copy];
  }
}

void ReturnFakeTasks(NSArray *tasks)
{
  [__fakeTasks release];
  __fakeTasks = [[NSMutableArray arrayWithArray:tasks] retain];

  if (tasks == nil) {
    SetTaskInstanceBlock(nil);
  } else {
    SetTaskInstanceBlock(^{
      assert(__fakeTasks.count > 0);
      NSTask *task = __fakeTasks[0];
      [__fakeTasks removeObjectAtIndex:0];
      return task;
    });
  }
}

NSDictionary *LaunchTaskAndCaptureOutput(NSTask *task)
{
  NSPipe *stdoutPipe = [NSPipe pipe];
  NSFileHandle *stdoutHandle = [stdoutPipe fileHandleForReading];

  NSPipe *stderrPipe = [NSPipe pipe];
  NSFileHandle *stderrHandle = [stderrPipe fileHandleForReading];

  __block NSString *standardOutput = nil;
  __block NSString *standardError = nil;

  void (^completionBlock)(NSNotification *) = ^(NSNotification *notification){
    NSData *data = notification.userInfo[NSFileHandleNotificationDataItem];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    if (notification.object == stdoutHandle) {
      standardOutput = str;
    } else if (notification.object == stderrHandle) {
      standardError = str;
    }

    CFRunLoopStop(CFRunLoopGetCurrent());
  };

  id stdoutObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleReadToEndOfFileCompletionNotification
                                                                        object:stdoutHandle
                                                                         queue:nil
                                                                    usingBlock:completionBlock];
  id stderrObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleReadToEndOfFileCompletionNotification
                                                                        object:stderrHandle
                                                                         queue:nil
                                                                    usingBlock:completionBlock];
  [stdoutHandle readToEndOfFileInBackgroundAndNotify];
  [stderrHandle readToEndOfFileInBackgroundAndNotify];
  [task setStandardOutput:stdoutPipe];
  [task setStandardError:stderrPipe];

  [task launch];
  [task waitUntilExit];

  while (standardOutput == nil || standardError == nil) {
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, YES);
  }

  [[NSNotificationCenter defaultCenter] removeObserver:stdoutObserver];
  [[NSNotificationCenter defaultCenter] removeObserver:stderrObserver];

  return @{@"stdout" : standardOutput, @"stderr" : standardError};
}

void LaunchTaskAndFeedOuputLinesToBlock(NSTask *task, void (^block)(NSString *))
{
  NSPipe *stdoutPipe = [NSPipe pipe];
  NSFileHandle *stdoutReadHandle = [stdoutPipe fileHandleForReading];
  NSFileHandle *stdoutWriteHandle = [stdoutPipe fileHandleForWriting];

  LineReader *reader = [[[LineReader alloc] initWithFileHandle:stdoutReadHandle] autorelease];
  reader.didReadLineBlock = block;

  [task setStandardOutput:stdoutWriteHandle];

  [reader startReading];

  [task launch];
  [task waitUntilExit];

  [reader stopReading];
  [stdoutWriteHandle closeFile];
  [reader finishReadingToEndOfFile];
}
