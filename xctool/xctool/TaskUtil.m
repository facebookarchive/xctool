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

#import "TaskUtil.h"

#import <poll.h>

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
    NSString *str = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

    if (notification.object == stdoutHandle) {
      standardOutput = [str retain];
    } else if (notification.object == stderrHandle) {
      standardError = [str retain];
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

  NSDictionary *output = @{@"stdout" : standardOutput, @"stderr" : standardError};

  [standardOutput release];
  [standardError release];

  return output;
}

void LaunchTaskAndFeedOuputLinesToBlock(NSTask *task, void (^block)(NSString *))
{
  NSPipe *stdoutPipe = [NSPipe pipe];
  int stdoutReadFD = [[stdoutPipe fileHandleForReading] fileDescriptor];

  int flags = fcntl(stdoutReadFD, F_GETFL, 0);
  NSCAssert(fcntl(stdoutReadFD, F_SETFL, flags | O_NONBLOCK) != -1,
            @"Failed to set O_NONBLOCK: %s", strerror(errno));

  NSMutableString *buffer = [[NSMutableString alloc] initWithCapacity:0];

  // Split whatever content we have in 'buffer' into lines.
  void (^processBuffer)(void) = ^{
    NSUInteger offset = 0;

    for (;;) {
      NSRange newlineRange = [buffer rangeOfString:@"\n"
                                           options:0
                                             range:NSMakeRange(offset, [buffer length] - offset)];
      if (newlineRange.length == 0) {
        break;
      } else {
        NSString *line = [buffer substringWithRange:NSMakeRange(offset, newlineRange.location - offset)];
        block(line);
        offset = newlineRange.location + 1;
      }
    }

    [buffer replaceCharactersInRange:NSMakeRange(0, offset) withString:@""];
  };

  // Uses poll() to block until data (or EOF) is available.
  BOOL (^pollForData)(int fd) = ^(int fd) {
    for (;;) {
      struct pollfd fds[1] = {0};
      fds[0].fd = fd;
      fds[0].events = (POLLIN | POLLHUP);

      int result = poll(fds,
                        sizeof(fds) / sizeof(fds[0]),
                        // wait as long as 1 second.
                        1000);

      if (result > 0) {
        // Data ready or EOF!
        return YES;
      } else if (result == 0) {
        // No data available.
        return NO;
      } else if (result == -1 && errno == EAGAIN) {
        // It could work next time.
        continue;
      } else {
        fprintf(stderr, "poll() failed with: %s\n", strerror(errno));
        abort();
      }
    }
  };

  // NSTask will automatically close the write-side of the pipe in our process, so only the new
  // process will have an open handle.  That means when that process exits, we'll automatically
  // see an EOF on the read-side since the last remaining ref to the write-side closed.
  [task setStandardOutput:stdoutPipe];

  [task launch];

  uint8_t readBuffer[32768] = {0};
  BOOL keepPolling = YES;

  while (keepPolling) {
    pollForData(stdoutReadFD);

    // Read whatever we can get.
    for (;;) {
      ssize_t bytesRead = read(stdoutReadFD, readBuffer, sizeof(readBuffer));
      if (bytesRead > 0) {
        @autoreleasepool {
          NSString *str = [[NSString alloc] initWithBytes:readBuffer length:bytesRead encoding:NSUTF8StringEncoding];
          [buffer appendString:str];
          [str release];

          processBuffer();
        }
      } else if ((bytesRead == 0) ||
                 (![task isRunning] && bytesRead == -1 && errno == EAGAIN)) {
        // We got an EOF - OR - we're calling it quits because the process has exited and it
        // appears there's no data left to be read.
        keepPolling = NO;
        break;
      } else if (bytesRead == -1 && errno == EAGAIN) {
        // Nothing left to read - poll() until more comes.
        break;
      } else if (bytesRead == -1) {
        fprintf(stderr, "read() failed with: %s\n", strerror(errno));
        abort();
      }
    }
  }

  [task waitUntilExit];
  [buffer release];
}
