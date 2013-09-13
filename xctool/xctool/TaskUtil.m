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

#import "NSConcreteTask.h"

static void readOutputs(NSString **outputs, int *fildes, int sz) {
  struct pollfd fds[sz];
  dispatch_data_t data[sz];

  for (int i = 0; i < sz; i++) {
    fds[i].fd = fildes[i];
    fds[i].events = POLLIN;
    fds[i].revents = 0;
    data[i] = dispatch_data_empty;
  }

  int remaining = sz;

  while (remaining > 0) {
    int pollResult = poll(fds, sz, -1);

    if (pollResult == -1) {
      switch (errno) {
        case EAGAIN:
        case EINTR:
          // poll can be restarted
          continue;
        default:
          NSLog(@"error during poll: %@",
                [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{}]);
          abort();
      }
    } else if (pollResult == 0) {
      NSCAssert(false, @"impossible, polling without timeout");
    } else {
      for (int i = 0; i < sz; i++) {
        if (fds[i].revents & (POLLIN | POLLHUP)) {
          void *buf = malloc(4096);
          ssize_t readResult = read(fds[i].fd, buf, 4096);

          if (readResult > 0) {  // some bytes read
            dispatch_data_t part =
              dispatch_data_create(buf,
                                   readResult,
                                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                                   // free() buf when this is destroyed.
                                   DISPATCH_DATA_DESTRUCTOR_FREE);
            dispatch_data_t combined = dispatch_data_create_concat(data[i], part);
            dispatch_release(part);
            dispatch_release(data[i]);
            data[i] = combined;
          } else if (readResult == 0) {  // eof
            remaining--;
            fds[i].fd = -1;
            fds[i].events = 0;
            free(buf);
          } else if (errno != EINTR) {
            NSLog(@"error during read: %@", [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{}]);
            abort();
          }
        }
      }
    }
  }

  for (int i = 0; i < sz; i++) {
    const void *dataPtr;
    size_t dataSz;
    dispatch_data_t contig = dispatch_data_create_map(data[i], &dataPtr, &dataSz);

    NSString *str = [[NSString alloc] initWithBytes:dataPtr length:dataSz encoding:NSUTF8StringEncoding];
    outputs[i] = str;

    dispatch_release(data[i]);
    dispatch_release(contig);
  }
}

NSDictionary *LaunchTaskAndCaptureOutput(NSTask *task)
{
  NSPipe *stdoutPipe = [NSPipe pipe];
  NSFileHandle *stdoutHandle = [stdoutPipe fileHandleForReading];

  NSPipe *stderrPipe = [NSPipe pipe];
  NSFileHandle *stderrHandle = [stderrPipe fileHandleForReading];

  [task setStandardOutput:stdoutPipe];
  [task setStandardError:stderrPipe];
  [task launch];

  NSString *outputs[2] = {nil, nil};
  int fides[2] = {stdoutHandle.fileDescriptor, stderrHandle.fileDescriptor};

  readOutputs(outputs, fides, 2);

  [task waitUntilExit];

  NSCAssert(outputs[0] != nil && outputs[1] != nil,
            @"output should have been populated");

  NSDictionary *output = @{@"stdout" : outputs[0], @"stderr" : outputs[1]};

  [outputs[0] release];
  [outputs[1] release];

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
  // see an EOF on the read-side since the last remaining ref to the write-side closed. (Corner
  // case: the process forks, the parent exits, but the kid keeps running with the FD open. We
  // handle that with the `[task isRunning]` check below.)
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

NSTask *CreateTaskInSameProcessGroup()
{
  NSConcreteTask *task = (NSConcreteTask *)[[NSTask alloc] init];
  [task setStartsNewProcessGroup:NO];
  return task;
}