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

#import "NSConcreteTask.h"
#import "SimDevice.h"
#import "SimulatorInfo.h"
#import "Swizzle.h"
#import "XCToolUtil.h"

typedef struct io_read_info {
  int fd;
  BOOL done;
  dispatch_io_t io;
  dispatch_data_t data;
  size_t processedBytes;
} io_read_info;

static NSArray *LinesFromDispatchData(dispatch_data_t data, BOOL omitNewlineCharacters, size_t *convertedSize, BOOL forceUntilTheEnd)
{
  const char *dataPtr;
  size_t dataSz;
  size_t processedSize = 0;

  if (data == NULL) {
    return @[];
  }

  dispatch_data_t contig = dispatch_data_create_map(data, (const void **)&dataPtr, &dataSz);
  NSMutableArray *lines = [@[] mutableCopy];

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

    dataPtr = newlineLocation + sizeof(char); // omit newline character

    [lines addObject:line];
  }

  if (convertedSize != NULL) {
    *convertedSize = processedSize;
  }

  dispatch_release(contig);
  return lines;
}

NSArray *ReadOutputsAndFeedOuputLinesToBlockOnQueue(
  int * const fildes,
  const int sz,
  FdOutputLineFeedBlock block,
  dispatch_queue_t queue,
  BlockToRunWhileReading blockToRunWhileReading,
  BOOL waitUntilFdsAreClosed)
{
  size_t (^feedUnprocessedLinesToBlock)(int, dispatch_data_t, BOOL) = ^(int fd, dispatch_data_t unprocessedPart, BOOL forceUntilTheEnd) {
    size_t processedSize;
    NSArray *lines = LinesFromDispatchData(unprocessedPart, YES, &processedSize, forceUntilTheEnd);
    dispatch_release(unprocessedPart);

    for (NSString *lineToFeed in lines) {
      if (queue == NULL) {
        block(fd, lineToFeed);
      } else {
        dispatch_async(queue, ^{
          block(fd, lineToFeed);
        });
      }
    }

    return processedSize;
  };

  io_read_info *infos = calloc(sz, sizeof(io_read_info));
  dispatch_group_t ioGroup = dispatch_group_create();
  for (int i = 0; i <sz; i++) {
    dispatch_group_enter(ioGroup);
    io_read_info *info = infos+i;
    (*info).fd = fildes[i];
    (*info).io = dispatch_io_create(DISPATCH_IO_STREAM, (*info).fd, dispatch_get_main_queue(), ^(int error) {
      if(error) {
        NSLog(@"[%d] Got an error while creating io for fd", (*info).fd);
      }
    });
    dispatch_io_set_low_water((*info).io, 1);
    dispatch_io_read((*info).io, 0, SIZE_MAX, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(bool done, dispatch_data_t data, int error) {
      if (error == ECANCELED) {
        return;
      }
      if (done) {
        (*info).done = YES;
      }
      if (!(*info).done && data != NULL) {
        if ((*info).data == NULL) {
          dispatch_retain(data);
          (*info).data = data;
        } else {
          dispatch_data_t combined = dispatch_data_create_concat((*info).data, data);
          dispatch_release((*info).data);
          (*info).data = combined;
        }
      }
      if (block && (*info).data != NULL) {
        // feed to block unprocessed lines
        size_t offset = (*info).processedBytes;
        size_t size = dispatch_data_get_size((*info).data);
        if (offset < size) {
          dispatch_data_t unprocessedPart = dispatch_data_create_subrange((*info).data, offset, size - offset);
          (*info).processedBytes += feedUnprocessedLinesToBlock((*info).fd, unprocessedPart, (*info).done);
        }
      }
      if ((*info).done) {
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

  NSMutableArray *outputs = [@[] mutableCopy];
  for (int i = 0; i < sz; i++) {
    io_read_info info = infos[i];
    NSString *output = [LinesFromDispatchData(info.data, NO, NULL, YES) componentsJoinedByString:@""];
    [outputs addObject:output];
    if (info.data != NULL) {
      dispatch_release(info.data);
    }
    close(info.fd);
    dispatch_io_close(info.io, DISPATCH_IO_STOP);
    dispatch_release(info.io);
  }

  free(infos);

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

  int fildes[2] = {stdoutHandle.fileDescriptor, stderrHandle.fileDescriptor};

  NSArray *outputs = ReadOutputsAndFeedOuputLinesToBlockOnQueue(fildes, 2, NULL, NULL, ^{
    LaunchTaskAndMaybeLogCommand(task, description);
    [task waitUntilExit];
  }, NO);

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

  int fildes[1] = {outputHandle.fileDescriptor};

  NSArray *outputs = ReadOutputsAndFeedOuputLinesToBlockOnQueue(fildes, 1, NULL, NULL, ^{
    LaunchTaskAndMaybeLogCommand(task, description);
    [task waitUntilExit];
  }, NO);

  NSCAssert(outputs[0] != nil,
            @"output should have been populated");

  return outputs[0];
}

void LaunchTaskAndFeedOuputLinesToBlock(NSTask *task, NSString *description, FdOutputLineFeedBlock block)
{
  NSPipe *stdoutPipe = [NSPipe pipe];
  int stdoutReadFD = [[stdoutPipe fileHandleForReading] fileDescriptor];

  [task setStandardOutput:stdoutPipe];

  int fildes[1] = {stdoutReadFD};

  ReadOutputsAndFeedOuputLinesToBlockOnQueue(fildes, 1, block, NULL, ^{
    LaunchTaskAndMaybeLogCommand(task, description);
    [task waitUntilExit];
  }, NO);
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
