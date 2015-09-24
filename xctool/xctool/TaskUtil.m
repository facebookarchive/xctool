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

#import <poll.h>

#import "NSConcreteTask.h"
#import "SimDevice.h"
#import "SimulatorInfo.h"
#import "Swizzle.h"
#import "XCToolUtil.h"

static NSString *StringFromDispatchData(dispatch_data_t data)
{
  const void *dataPtr;
  size_t dataSz;
  dispatch_data_t contig = dispatch_data_create_map(data, &dataPtr, &dataSz);
  NSString *str = [[NSString alloc] initWithBytes:dataPtr length:dataSz encoding:NSUTF8StringEncoding];
  dispatch_release(contig);
  return str;
}

static NSArray *readOutputs(int *fildes, int sz)
{
  return ReadOutputsAndFeedOuputLinesToBlockOnQueue(fildes, sz, nil, NULL);
}

NSArray *ReadOutputsAndFeedOuputLinesToBlockOnQueue(
  int * const fildes,
  const int sz,
  FdOutputLineFeedBlock block,
  dispatch_queue_t queue)
{
  NSMutableArray *outputs = [NSMutableArray arrayWithCapacity:sz];
  struct pollfd fds[sz];
  dispatch_data_t data[sz];
  size_t processedBytes[sz];

  size_t (^feedUnprocessedLinesToBlock)(dispatch_data_t, BOOL) = ^(dispatch_data_t unprocessedPart, BOOL forceUntilTheEnd) {
    NSString *string = StringFromDispatchData(unprocessedPart);
    dispatch_release(unprocessedPart);
    size_t processedStringLength = string.length;
    NSMutableArray *lines = [[string componentsSeparatedByString:@"\n"] mutableCopy];
    // if not forced to feed bytes until the end then skip lines not having "\n" suffix
    if (!forceUntilTheEnd && ![string hasSuffix:@"\n"]) {
      NSString *skippedLine = [lines lastObject];
      if (skippedLine) {
        [lines removeLastObject];
        processedStringLength -= skippedLine.length;
      }
    }
    for (NSString *lineToFeed in lines) {
      if (lineToFeed.length == 0) {
        continue;
      }
      if (queue == NULL) {
        block(lineToFeed);
      } else {
        dispatch_async(queue, ^{
          block(lineToFeed);
        });
      }
    }
    return processedStringLength;
  };

  for (int i = 0; i < sz; i++) {
    fds[i].fd = fildes[i];
    fds[i].events = POLLIN;
    fds[i].revents = 0;
    data[i] = dispatch_data_empty;
    processedBytes[i] = 0;
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
        if (!(fds[i].revents & (POLLIN | POLLHUP))) {
          continue;
        }

        uint8_t buf[4096] = {0};
        ssize_t readResult = read(fds[i].fd, buf, (sizeof(buf) / sizeof(uint8_t)));

        if (readResult > 0) {  // some bytes read
          dispatch_data_t part =
            dispatch_data_create(buf,
                                 readResult,
                                 dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                                 // copy data from the buffer
                                 DISPATCH_DATA_DESTRUCTOR_DEFAULT);
          dispatch_data_t combined = dispatch_data_create_concat(data[i], part);
          dispatch_release(part);
          dispatch_release(data[i]);
          data[i] = combined;
        } else if (readResult == 0) {  // eof
          remaining--;
          fds[i].fd = -1;
          fds[i].events = 0;
        } else if (errno != EINTR) {
          NSLog(@"error during read: %@", [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{}]);
          abort();
        }
        if (block) {
          // feed to block unprocessed lines
          size_t offset = processedBytes[i];
          size_t size = dispatch_data_get_size(data[i]);
          dispatch_data_t unprocessedPart = dispatch_data_create_subrange(data[i], offset, size - offset);
          processedBytes[i] += feedUnprocessedLinesToBlock(unprocessedPart, fds[i].fd == -1);
        }
      }
    }
  }

  for (int i = 0; i < sz; i++) {
    NSString *str = StringFromDispatchData(data[i]);
    [outputs addObject:str];
    dispatch_release(data[i]);
  }

  return outputs;
}

NSDictionary *LaunchTaskAndCaptureOutput(NSTask *task, NSString *description)
{
  NSPipe *stdoutPipe = [NSPipe pipe];
  NSFileHandle *stdoutHandle = [stdoutPipe fileHandleForReading];

  NSPipe *stderrPipe = [NSPipe pipe];
  NSFileHandle *stderrHandle = [stderrPipe fileHandleForReading];

  [task setStandardOutput:stdoutPipe];
  [task setStandardError:stderrPipe];
  LaunchTaskAndMaybeLogCommand(task, description);

  int fides[2] = {stdoutHandle.fileDescriptor, stderrHandle.fileDescriptor};

  NSArray *outputs = readOutputs(fides, 2);

  [task waitUntilExit];

  NSCAssert(outputs[0] != nil && outputs[1] != nil,
            @"output should have been populated");

  NSDictionary *output = @{@"stdout" : outputs[0], @"stderr" : outputs[1]};

  return output;
}

NSString *LaunchTaskAndCaptureOutputInCombinedStream(NSTask *task, NSString *description)
{
  NSPipe *outputPipe = [NSPipe pipe];
  NSFileHandle *outputHandle = [outputPipe fileHandleForReading];

  [task setStandardOutput:outputPipe];
  [task setStandardError:outputPipe];
  LaunchTaskAndMaybeLogCommand(task, description);

  int fides[1] = {outputHandle.fileDescriptor};

  NSArray *outputs = readOutputs(fides, 1);

  [task waitUntilExit];

  NSCAssert(outputs[0] != nil,
            @"output should have been populated");

  return outputs[0];
}

void LaunchTaskAndFeedOuputLinesToBlock(NSTask *task, NSString *description, ReporterEventFeedBlock block)
{
  NSPipe *stdoutPipe = [NSPipe pipe];
  int stdoutReadFD = [[stdoutPipe fileHandleForReading] fileDescriptor];

  int flags = fcntl(stdoutReadFD, F_GETFL, 0);
  NSCAssert(fcntl(stdoutReadFD, F_SETFL, flags | O_NONBLOCK) != -1,
            @"Failed to set O_NONBLOCK: %s", strerror(errno));

  int fildes[1] = {stdoutReadFD};

  // NSTask will automatically close the write-side of the pipe in our process, so only the new
  // process will have an open handle.  That means when that process exits, we'll automatically
  // see an EOF on the read-side since the last remaining ref to the write-side closed. (Corner
  // case: the process forks, the parent exits, but the kid keeps running with the FD open. We
  // handle that with the `[task isRunning]` check below.)
  [task setStandardOutput:stdoutPipe];

  LaunchTaskAndMaybeLogCommand(task, description);

  ReadOutputsAndFeedOuputLinesToBlockOnQueue(fildes, 1, block, NULL);

  [task waitUntilExit];
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

NSTask *CreateTaskForSimulatorExecutable(NSString *sdkName,
                                         SimulatorInfo *simulatorInfo,
                                         NSString *launchPath,
                                         NSArray *arguments,
                                         NSDictionary *environment)
{
  NSTask *task = CreateTaskInSameProcessGroup();
  NSMutableArray *taskArgs = [NSMutableArray array];
  NSMutableDictionary *taskEnv = [NSMutableDictionary dictionary];

  if ([sdkName hasPrefix:@"iphonesimulator"]) {
    [taskArgs addObjectsFromArray:@[
      @"spawn",
      [[[simulatorInfo simulatedDevice] UDID] UUIDString],
    ]];
    [taskArgs addObject:launchPath];
    [taskArgs addObjectsFromArray:arguments];

    [environment enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop){
      // simctl has a bug where it hangs if an empty child environment variable is set.
      if ([val length] == 0) {
        return;
      }

      // simctl will look for all vars prefixed with SIMCTL_CHILD_ and add them
      // to the spawned process's environment (with the prefix removed).
      NSString *newKey = [@"SIMCTL_CHILD_" stringByAppendingString:key];
      taskEnv[newKey] = val;
    }];

    [task setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/simctl"]];
  } else {
    [task setLaunchPath:launchPath];
    [taskArgs addObjectsFromArray:arguments];
    [taskEnv addEntriesFromDictionary:environment];
  }

  [task setArguments:taskArgs];
  [task setEnvironment:taskEnv];

  return task;
}
