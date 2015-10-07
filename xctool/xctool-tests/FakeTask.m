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

#import "FakeTask.h"

#import <objc/message.h>
#import <objc/runtime.h>

#import "FakeTaskManager.h"

static NSString * const kSIMCTL_OTEST_SHIM_STDOUT_FILE = @"SIMCTL_CHILD_OTEST_SHIM_STDOUT_FILE";
static NSString * const kOTEST_SHIM_STDOUT_FILE = @"OTEST_SHIM_STDOUT_FILE";

static void writeAll(int fildes, const void *buf, size_t nbyte) {
  while (nbyte > 0) {
    ssize_t written = write(fildes, buf, nbyte);
    NSCAssert(written > 0, @"write should succeed in writing");
    nbyte -= written;
    buf += written;
  }
}

// method defined in otest-shim.
void __exit(int code);

@interface FakeTask ()
@property (atomic, assign, readwrite) int terminationStatus;
@end

@implementation FakeTask {
  pid_t _forkedPid;
}
@synthesize currentDirectoryPath = _currentDirectoryPath;
@synthesize launchPath = _launchPath;
@synthesize arguments = _arguments;
@synthesize environment = _environment;
@synthesize standardOutput = _standardOutput;
@synthesize standardError = _standardError;
@synthesize terminationStatus = _terminationStatus;

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus
                 terminationReason:(NSTaskTerminationReason)pretendTerminationReason
                standardOutputPath:(NSString *)standardOutputPath
                 standardErrorPath:(NSString *)standardErrorPath
{
  FakeTask *task = [[FakeTask alloc] init];
  [task pretendTerminationReason:pretendTerminationReason];
  [task pretendExitStatusOf:exitStatus];
  [task pretendTaskReturnsStandardOutput:
   [NSString stringWithContentsOfFile:standardOutputPath
                             encoding:NSUTF8StringEncoding
                                error:nil]];
  [task pretendTaskReturnsStandardError:
   [NSString stringWithContentsOfFile:standardErrorPath
                             encoding:NSUTF8StringEncoding
                                error:nil]];
  return task;
}

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus
{
  return [self fakeTaskWithExitStatus:exitStatus
                    terminationReason:NSTaskTerminationReasonExit
                   standardOutputPath:nil
                    standardErrorPath:nil];
}

- (void)pretendTaskReturnsStandardOutput:(NSString *)str
{
  if (str != _pretendStandardOutput) {
    _pretendStandardOutput = str;
  }
}

- (void)pretendTaskReturnsStandardError:(NSString *)str
{
  if (str != _pretendStandardError) {
    _pretendStandardError = str;
  }
}

- (void)pretendExitStatusOf:(int)exitStatus
{
  _pretendExitStatus = exitStatus;
}

- (void)pretendTerminationReason:(NSTaskTerminationReason)reason
{
  _pretendTerminationReason = reason;
}

- (instancetype)init
{
  if (self = [super init]) {
  }
  return self;
}


- (void)launch
{
  FakeTaskManager *manager = [FakeTaskManager sharedManager];
  if ([manager fakeTasksAreEnabled]) {
    [manager recordLaunchedTask:self];
    [manager callLaunchHandlersWithTask:self];
  }

  NSData *pretendStandardOutputData = nil;
  if (_pretendStandardOutput) {
    pretendStandardOutputData = [_pretendStandardOutput
                                 dataUsingEncoding:NSUTF8StringEncoding];
  } else {
    pretendStandardOutputData = [NSData dataWithBytes:NULL length:0];
  }

  NSData *pretendStandardErrorData = nil;
  if (_pretendStandardError) {
    pretendStandardErrorData = [_pretendStandardError
                                dataUsingEncoding:NSUTF8StringEncoding];
  } else {
    pretendStandardErrorData = [NSData dataWithBytes:NULL length:0];
  }

  const void *pretendStandardOutputBytes = [pretendStandardOutputData bytes];
  const void *pretendStandardErrorBytes = [pretendStandardErrorData bytes];
  NSUInteger pretendStandardOutputLength = [pretendStandardOutputData length];
  NSUInteger pretendStandardErrorLength = [pretendStandardErrorData length];

  int standardOutputWriteFd = -1;
  BOOL standardOutputIsAPipe = NO;
  if ([_standardOutput isKindOfClass:[NSPipe class]]) {
    standardOutputWriteFd = [[_standardOutput fileHandleForWriting] fileDescriptor];
    standardOutputIsAPipe = YES;
  } else if ([_standardOutput isKindOfClass:[NSFileHandle class]]) {
    standardOutputWriteFd = [_standardOutput fileDescriptor];
    standardOutputIsAPipe = NO;
  }

  int standardErrorWriteFd = -1;
  BOOL standardErrorIsAPipe = NO;
  if ([_standardError isKindOfClass:[NSPipe class]]) {
    standardErrorWriteFd = [[_standardError fileHandleForWriting] fileDescriptor];
    standardErrorIsAPipe = YES;
  } else if ([_standardError isKindOfClass:[NSFileHandle class]]) {
    standardErrorWriteFd = [_standardError fileDescriptor];
    standardErrorIsAPipe = NO;
  }

  NSString *otestShimStdoutFilePath = _environment[kOTEST_SHIM_STDOUT_FILE] ?: _environment[kSIMCTL_OTEST_SHIM_STDOUT_FILE];
  if (otestShimStdoutFilePath) {
    // we need to open for writing and close because on the other side
    // there is blocking opening for read.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      int otestShimOutputWriteFD = -1;
      otestShimOutputWriteFD = open([otestShimStdoutFilePath UTF8String], O_WRONLY);
      close(otestShimOutputWriteFD);
    });
  }

  [self setIsRunning:YES];

  pid_t forkedPid = fork();
  NSAssert(forkedPid != -1, @"fork() failed with: %s", strerror(errno));

  if (forkedPid == 0) {
    if (standardOutputWriteFd != -1) {
      writeAll(standardOutputWriteFd, pretendStandardOutputBytes, pretendStandardOutputLength);
      close(standardOutputWriteFd);
    }
    if (standardErrorWriteFd != -1) {
      writeAll(standardErrorWriteFd, pretendStandardErrorBytes, pretendStandardErrorLength);
      close(standardErrorWriteFd);
    }

    // call directly to interposed in otest-shim exit.
    __exit(0);
  } else {
    // If we're working with pipes, we need to make sure we close the
    // write side in the host process - otherwise the pipe never becomes
    // 'widowed' and so the EOF never comes.
    if (standardOutputIsAPipe) {
      close(standardOutputWriteFd);
    }
    if (standardErrorIsAPipe) {
      close(standardErrorWriteFd);
    }

    _forkedPid = forkedPid;
  }

}

- (void)waitUntilExit
{
  int pidStatus = 0;
  if (_forkedPid > 0) {
    waitpid(_forkedPid, &pidStatus, 0);
  }
  [self setTerminationStatus:_pretendExitStatus];
  [self setIsRunning:NO];
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"<FakeTask launchPath='%@', arguments=%@>",
          [self launchPath],
          [self arguments]];
}

- (void)setPreferredArchitectures:(NSArray *)architectures
{
  // This is part of NSConcreteTask - we're fine if it's a no-op in tests.
}

- (void)setStartsNewProcessGroup:(BOOL)startsNewProcessGroup
{
  // This is part of NSConcreteTask - we're fine if it's a no-op in tests.
}

#pragma mark - Setters & Getters

- (NSTaskTerminationReason)terminationReason
{
  return _pretendTerminationReason;
}

- (void)setTerminationReason:(NSTaskTerminationReason)terminationReason
{
  // empty implementation
}

@end
