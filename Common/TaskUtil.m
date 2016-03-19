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

#import "TaskUtil.h"

#import <iconv.h>

#import <sys/stat.h>

#import "EventGenerator.h"
#import "NSConcreteTask.h"
#import "Swizzle.h"
#import "XCToolUtil.h"

typedef struct io_read_info {
  int fd;
  BOOL done;
  dispatch_io_t io;
  dispatch_data_t data;
  BOOL trailingNewline;
} io_read_info;

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

NSString *StringFromDispatchDataWithBrokenUTF8Encoding(const char *dataPtr, size_t dataSz)
{
  int one = 1;
  iconv_t cd = iconv_open("UTF-8", "UTF-8");
  iconvctl(cd, ICONV_SET_DISCARD_ILSEQ, &one);
  char *inbuf  = (char *)dataPtr;
  char *outbuf = malloc(sizeof(char) * dataSz);
  NSMutableString *outputString = [NSMutableString string];
  long bytesToProcess = dataSz;
  while (bytesToProcess > 0) {
    NSString *string = nil;
    size_t inbytesleft = bytesToProcess;
    size_t outbytesleft = bytesToProcess;
    char *outptr = outbuf;
    size_t iconvResult = iconv(cd, &inbuf, &inbytesleft, &outptr, &outbytesleft);
    size_t outbytesLength = bytesToProcess - outbytesleft;
    if (outbytesLength > 0) {
      string = [[NSString alloc] initWithBytesNoCopy:outbuf length:outbytesLength encoding:NSUTF8StringEncoding freeWhenDone:NO];
      [outputString appendString:string];
    }
    if (iconvResult != (size_t)-1) {
      inbuf += (bytesToProcess - inbytesleft);
    } else if (errno == EINVAL) {
      // skip first byte and then all next 10xxxxxx bytes (see UTF-8 description for more details)
      do {
        inbuf++;
        inbytesleft--;
      } while (((*inbuf) & 0xC0) == 0x80 && inbytesleft > 0);
      [outputString appendString:@"\uFFFD"];
    }
    bytesToProcess = inbytesleft;
  }
  free(outbuf);
  iconv_close(cd);
  return outputString;
}

static NSArray *LinesFromDispatchData(dispatch_data_t data, BOOL omitNewlineCharacters, BOOL forceUntilTheEnd, size_t *convertedSize)
{
  const char *dataPtr;
  size_t dataSz;
  size_t processedSize = 0;

  if (data == NULL) {
    return @[];
  }

  dispatch_data_t contig = dispatch_data_create_map(data, (const void **)&dataPtr, &dataSz);
  NSMutableArray *lines = [NSMutableArray new];

  while (processedSize < dataSz) {
    size_t lineLength;
    const char *newlineLocation = memchr(dataPtr, '\n', dataSz - processedSize);
    if (newlineLocation == NULL) {
      if (!forceUntilTheEnd) {
        break;
      }
      // process remaining bytes
      lineLength = dataSz - processedSize;
      processedSize += lineLength;
    } else {
      lineLength = newlineLocation - dataPtr + (omitNewlineCharacters ? 0 : sizeof(char));
      processedSize += lineLength + (omitNewlineCharacters ? sizeof(char) : 0);
    }

    NSString *line = [[NSString alloc] initWithBytes:dataPtr length:lineLength encoding:NSUTF8StringEncoding];

    if (!line) {
      // discard invalid UTF-8 characters in the data
      line = StringFromDispatchDataWithBrokenUTF8Encoding(dataPtr, lineLength);
    }

    dataPtr = newlineLocation + sizeof(char); // omit newline character

    [lines addObject:line];
  }

  if (convertedSize != NULL) {
    *convertedSize = processedSize;
  }

  dispatch_release(contig);
  return lines;
}

void ReadOutputsAndFeedOuputLinesToBlockOnQueue(
  int * const fildes,
  const int sz,
  FdOutputLineFeedBlock block,
  dispatch_queue_t queue,
  BlockToRunWhileReading blockToRunWhileReading,
  BOOL waitUntilFdsAreClosed)
{
  void (^callOutputLineFeedBlock)(int, NSString *) = ^(int fd, NSString *lineToFeed) {
    if (queue == NULL) {
      block(fd, lineToFeed);
    } else {
      dispatch_async(queue, ^{
        block(fd, lineToFeed);
      });
    }
  };

  size_t (^feedUnprocessedLinesToBlock)(int, dispatch_data_t, BOOL) = ^(int fd, dispatch_data_t unprocessedPart, BOOL forceUntilTheEnd) {
    size_t processedSize;
    NSArray *lines = LinesFromDispatchData(unprocessedPart, YES, forceUntilTheEnd, &processedSize);

    for (NSString *lineToFeed in lines) {
      callOutputLineFeedBlock(fd, lineToFeed);
    }

    return processedSize;
  };

  NSString *ioQueueName = [NSString stringWithFormat:@"com.facebook.xctool.%f.%d", [[NSDate date] timeIntervalSince1970], fildes[0]];
  dispatch_queue_t ioQueue = dispatch_queue_create([ioQueueName UTF8String], DISPATCH_QUEUE_SERIAL);
  io_read_info *infos = calloc(sz, sizeof(io_read_info));
  dispatch_group_t ioGroup = dispatch_group_create();
  for (int i = 0; i < sz; i++) {
    dispatch_group_enter(ioGroup);
    io_read_info *info = infos+i;
    info->fd = fildes[i];
    info->io = dispatch_io_create(DISPATCH_IO_STREAM, info->fd, dispatch_get_main_queue(), ^(int error) {
      if(error) {
        NSLog(@"[%d] Got an error while creating io for fd", info->fd);
      }
    });
    dispatch_io_set_low_water(info->io, 1);
    dispatch_io_read(info->io, 0, SIZE_MAX, ioQueue, ^(bool done, dispatch_data_t data, int error) {
      if (error == ECANCELED) {
        return;
      }
      if (info->done) {
        return;
      }
      if (done) {
        info->done = YES;
      }
      if (!info->done && data != NULL) {
        if (info->data == NULL) {
          dispatch_retain(data);
          info->data = data;
        } else {
          dispatch_data_t combined = dispatch_data_create_concat(info->data, data);
          dispatch_release(info->data);
          info->data = combined;
        }
      }
      if (block && info->data != NULL) {
        // feed to block unprocessed lines
        size_t size = dispatch_data_get_size(info->data);
        if (size > 0) {
          size_t chomped = feedUnprocessedLinesToBlock(info->fd, info->data, info->done);

          // Check for trailing newline before advancing the buffer, this will
          // be used to determine whether to emit an empty line should the
          // stream end in a newline, which would otherwise be omitted.
          if (chomped > 0) {
            dispatch_data_t data = dispatch_data_create_subrange(info->data, chomped - 1, 1);
            const char *lastCharPtr;
            dispatch_data_t ch = dispatch_data_create_map(data, (const void **)&lastCharPtr, NULL);
            info->trailingNewline = (*lastCharPtr == '\n');
            dispatch_release(ch);
            dispatch_release(data);
          }

          dispatch_data_t remaining = dispatch_data_create_subrange(info->data, chomped, size - chomped);
          dispatch_release(info->data);
          info->data = remaining;
        }
      }
      if (info->done) {
        dispatch_group_leave(ioGroup);
      }
    });
  }

  if (blockToRunWhileReading != NULL) {
    blockToRunWhileReading();
  }

  // wait for ios to be closed
  dispatch_time_t timeout = DISPATCH_TIME_FOREVER;
  if (!waitUntilFdsAreClosed) {
    timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC * 500);
  }
  dispatch_group_wait(ioGroup, timeout);
  // synchronously wait for all events on the feed queue to be processed
  if (queue) {
    dispatch_sync(queue, ^{});
  }

  for (int i = 0; i < sz; i++) {
    io_read_info *info = infos+i;
    dispatch_sync(ioQueue, ^{
      if (!info->done) {
        dispatch_group_leave(ioGroup);
        info->done = YES;
      }
      if (info->trailingNewline) {
        callOutputLineFeedBlock(info->fd, @"");
      }
      if (info->data != NULL) {
        dispatch_release(info->data);
      }
      close(info->fd);
      dispatch_io_close(info->io, DISPATCH_IO_STOP);
      dispatch_release(info->io);
    });
  }

  dispatch_release(ioGroup);
  dispatch_release(ioQueue);
  free(infos);
}

NSDictionary *LaunchTaskAndCaptureOutput(NSTask *task, NSString *description)
{
  int stdoutPipefd[2];
  pipe(stdoutPipefd);
  NSFileHandle *stdoutHandle = [[NSFileHandle alloc] initWithFileDescriptor:stdoutPipefd[1]];
  int stdoutReadFd = stdoutPipefd[0];

  int stderrPipefd[2];
  pipe(stderrPipefd);
  NSFileHandle *stderrHandle = [[NSFileHandle alloc] initWithFileDescriptor:stderrPipefd[1]];
  int stderrReadFd = stderrPipefd[0];

  [task setStandardOutput:stdoutHandle];
  [task setStandardError:stderrHandle];

  int fildes[2] = {stdoutReadFd, stderrReadFd};

  NSMutableArray *stdoutArray = [NSMutableArray new];
  NSMutableArray *stderrArray = [NSMutableArray new];

  ReadOutputsAndFeedOuputLinesToBlockOnQueue(fildes, 2, ^(int fd, NSString *line) {
    if (fd == stdoutReadFd) {
      [stdoutArray addObject:line];
    } else if (fd == stderrReadFd) {
      [stderrArray addObject:line];
    }
  }, NULL, ^{
    LaunchTaskAndMaybeLogCommand(task, description);
    [task waitUntilExit];
    [stdoutHandle closeFile];
    [stderrHandle closeFile];
  }, YES);

  NSString *stdoutOutput = [stdoutArray componentsJoinedByString:@"\n"];
  NSString *stderrOutput = [stderrArray componentsJoinedByString:@"\n"];

  NSDictionary *output = @{@"stdout": stdoutOutput, @"stderr": stderrOutput};

  return output;
}

NSString *LaunchTaskAndCaptureOutputInCombinedStream(NSTask *task, NSString *description)
{
  int stdoutPipefd[2];
  pipe(stdoutPipefd);
  NSFileHandle *stdoutHandle = [[NSFileHandle alloc] initWithFileDescriptor:stdoutPipefd[1]];
  int stdoutReadFd = stdoutPipefd[0];

  [task setStandardOutput:stdoutHandle];
  [task setStandardError:stdoutHandle];

  int fildes[1] = {stdoutReadFd};

  NSMutableArray *lines = [NSMutableArray new];

  ReadOutputsAndFeedOuputLinesToBlockOnQueue(fildes, 1, ^(int fd, NSString *line) {
    [lines addObject:line];
  }, NULL, ^{
    LaunchTaskAndMaybeLogCommand(task, description);
    [task waitUntilExit];
    [stdoutHandle closeFile];
  }, YES);

  return [lines componentsJoinedByString:@"\n"];
}

void LaunchTaskAndFeedOuputLinesToBlock(NSTask *task, NSString *description, FdOutputLineFeedBlock block)
{
  int stdoutPipefd[2];
  pipe(stdoutPipefd);
  NSFileHandle *stdoutHandle = [[NSFileHandle alloc] initWithFileDescriptor:stdoutPipefd[1]];
  int stdoutReadFd = stdoutPipefd[0];

  [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
  [task setStandardOutput:stdoutHandle];

  int fildes[1] = {stdoutReadFd};

  ReadOutputsAndFeedOuputLinesToBlockOnQueue(fildes, 1, block, NULL, ^{
    LaunchTaskAndMaybeLogCommand(task, description);
    [task waitUntilExit];
    [stdoutHandle closeFile];
  }, YES);
}

void LaunchTaskAndFeedSimulatorOutputAndOtestShimEventsToBlock(
  NSTask *task,
  NSString *description,
  NSString *otestShimOutputFilePath,
  FdOutputLineFeedBlock block)
{
  // intercept stdout, stderr and post as simulator-output events
  int stdoutPipefd[2];
  pipe(stdoutPipefd);
  NSFileHandle *stdoutHandle = [[NSFileHandle alloc] initWithFileDescriptor:stdoutPipefd[1]];
  int stdoutReadFd = stdoutPipefd[0];

  // stdout and stderr is forwarded to the same pipe
  // that way xctool preserves an order of printed lines
  [task setStandardOutput:stdoutHandle];
  [task setStandardError:stdoutHandle];

  int mkfifoResult = mkfifo([otestShimOutputFilePath UTF8String], S_IWUSR | S_IRUSR | S_IRGRP);
  NSCAssert(mkfifoResult == 0, @"Failed to create a fifo at path: %@", otestShimOutputFilePath);

  /*
   * We need to launch task before trying to open the pipe for reading. Once
   * otest-shim opens the pipe for writing we will get `otestShimOutputReadFD`.
   * If open the pipe with `O_NONBLOCK` `dispatch_io_read` returns
   * `done` immideately.
   */
  LaunchTaskAndMaybeLogCommand(task, description);

  // intercept otest-shim events and post as-is
  int otestShimOutputReadFD = open([otestShimOutputFilePath UTF8String], O_RDONLY);

  int fildes[2] = {stdoutReadFd, otestShimOutputReadFD};
  NSString *feedQueueName = [NSString stringWithFormat:@"com.facebook.events.feed.queue.%f.%d", [[NSDate date] timeIntervalSince1970], fildes[1]];
  dispatch_queue_t feedQueue = dispatch_queue_create([feedQueueName UTF8String], DISPATCH_QUEUE_SERIAL);
  ReadOutputsAndFeedOuputLinesToBlockOnQueue(fildes, 2, ^(int fd, NSString *line) {
    if (fd != otestShimOutputReadFD) {
      NSDictionary *event = EventDictionaryWithNameAndContent(
        kReporter_Events_SimulatorOuput,
        @{kReporter_SimulatorOutput_OutputKey: StripAnsi([line stringByAppendingString:@"\n"])}
      );
      NSData *data = [NSJSONSerialization dataWithJSONObject:event options:0 error:nil];
      line = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    if (line) {
      block(fd, line);
    }
  },
  // all events should be processed serially on the same queue
  feedQueue,
  ^{
    [task waitUntilExit];
    [stdoutHandle closeFile];
  },
  // when xctest aborts it doesn't always close pipes properly so
  // xctool shouldn't wait for them to be closed after simctl exits
  NO);
}

NSTask *CreateTaskInSameProcessGroupWithArch(cpu_type_t arch)
{
  NSConcreteTask *task = (NSConcreteTask *)CreateTaskInSameProcessGroup();
  if (arch != CPU_TYPE_ANY) {
    NSCAssert(arch == CPU_TYPE_I386 || arch == CPU_TYPE_X86_64, @"CPU type should either be i386 or x86_64.");
    [task setPreferredArchitectures:@[ @(arch) ]];
  }
  return task;
}

NSTask *CreateTaskInSameProcessGroup()
{
  NSConcreteTask *task = (NSConcreteTask *)[[NSTask alloc] init];
  NSCAssert([task respondsToSelector:@selector(setStartsNewProcessGroup:)], @"The created task doesn't respond to the -setStartsNewProcessGroup:, which means it probably isn't a NSConcreteTask instance.");
  [task setStartsNewProcessGroup:NO];
  return task;
}

NSTask *CreateConcreteTaskInSameProcessGroup()
{
  NSConcreteTask *task = nil;

  if (IsRunningUnderTest()) {
    task = [objc_msgSend([NSTask class],
                         @selector(__NSTask_allocWithZone:),
                         NSDefaultMallocZone()) init];
    [task setStartsNewProcessGroup:NO];
    return task;
  } else {
    return CreateTaskInSameProcessGroup();
  }
}

static NSString *QuotedStringIfNeeded(NSString *str) {
  if ([str rangeOfString:@" "].length > 0) {
    return (NSString *)[NSString stringWithFormat:@"\"%@\"", str];
  } else {
    return str;
  }
}

static NSString *CommandLineEquivalentForTaskArchSpecificTask(NSConcreteTask *task, cpu_type_t cpuType)
{
  NSMutableString *buffer = [NSMutableString string];

  NSString *archString = nil;

  if (cpuType == CPU_TYPE_I386) {
    archString = @"i386";
  } else if (cpuType == CPU_TYPE_X86_64) {
    archString = @"x86_64";
  } else {
    NSCAssert(NO, @"Unexepcted cpu type %d", cpuType);
  }

  [buffer appendFormat:@"/usr/bin/arch -arch %@ \\\n", archString];

  [[task environment] enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *val, BOOL *stop){
    [buffer appendFormat:@"  -e %@=%@ \\\n", key, QuotedStringIfNeeded(val)];
  }];

  [buffer appendFormat:@"  %@", QuotedStringIfNeeded(task.launchPath)];

  if (task.arguments.count > 0) {
    [buffer appendFormat:@" \\\n"];

    for (NSUInteger i = 0; i < task.arguments.count; i++) {
      if (i == (task.arguments.count - 1)) {
        [buffer appendFormat:@"    %@", QuotedStringIfNeeded(task.arguments[i])];
      } else {
        [buffer appendFormat:@"    %@ \\\n", QuotedStringIfNeeded(task.arguments[i])];
      }
    }
  }

  return buffer;
}

static NSString *CommandLineEquivalentForTaskArchGenericTask(NSConcreteTask *task) {
  NSMutableString *buffer = [NSMutableString string];

  [[task environment] enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *val, BOOL *stop){
    [buffer appendFormat:@"  %@=%@ \\\n", key, QuotedStringIfNeeded(val)];
  }];

  NSCAssert(task.launchPath != nil, @"Should have a launchPath");
  [buffer appendFormat:@"  %@", QuotedStringIfNeeded(task.launchPath)];

  if (task.arguments.count > 0) {
    [buffer appendFormat:@" \\\n"];

    for (NSUInteger i = 0; i < task.arguments.count; i++) {
      if (i == (task.arguments.count - 1)) {
        [buffer appendFormat:@"    %@", QuotedStringIfNeeded(task.arguments[i])];
      } else {
        [buffer appendFormat:@"    %@ \\\n", QuotedStringIfNeeded(task.arguments[i])];
      }
    }
  }

  return buffer;
}

NSString *CommandLineEquivalentForTask(NSConcreteTask *task)
{
  NSCAssert(task.launchPath != nil, @"Should have a launchPath");

  NSArray *preferredArchs = [task preferredArchitectures];
  if (preferredArchs != nil && preferredArchs.count > 0) {
    return CommandLineEquivalentForTaskArchSpecificTask(task, [preferredArchs[0] intValue]);
  } else {
    return CommandLineEquivalentForTaskArchGenericTask(task);
  }
}

void LaunchTaskAndMaybeLogCommand(NSTask *task, NSString *description)
{
  NSArray *arguments = [[NSProcessInfo processInfo] arguments];

  // Instead of using `-[Options showCommands]`, we look directly at the process
  // arguments.  This has two advantages: 1) we can start logging commands even
  // before Options gets parsed/initialized, and 2) we don't have to add extra
  // plumbing so that the `Options` instance gets passed into this function.
  if ([arguments containsObject:@"-showTasks"] ||
      [arguments containsObject:@"--showTasks"]) {

    NSMutableString *buffer = [NSMutableString string];
    [buffer appendFormat:@"\n================================================================================\n"];
    [buffer appendFormat:@"LAUNCHING TASK (%@):\n\n", description];
    [buffer appendFormat:@"%@\n", CommandLineEquivalentForTask((NSConcreteTask *)task)];
    [buffer appendFormat:@"================================================================================\n"];
    fprintf(stderr, "%s", [buffer UTF8String]);
    fflush(stderr);
  }

  [task launch];
}
