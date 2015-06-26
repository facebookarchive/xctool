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

#import "ReporterTask.h"

#import <fcntl.h>
#import <objc/message.h>

#import "NSFileHandle+Print.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"

@interface ReporterTask ()
@property (nonatomic, copy) NSString *reporterPath;
@property (nonatomic, copy) NSString *outputPath;

@property (nonatomic, strong) NSFileHandle *standardOutput;
@property (nonatomic, strong) NSFileHandle *standardError;

@property (nonatomic, assign) BOOL outputPathIsFile;

@property (nonatomic, strong) NSTask *task;
@property (nonatomic, strong) NSPipe *pipe;

@property (nonatomic, assign) BOOL wasOpened;
@property (nonatomic, assign) BOOL wasClosed;
@end

@implementation ReporterTask

- (instancetype)initWithReporterPath:(NSString *)reporterPath
                          outputPath:(NSString *)outputPath
{
  if (self = [super init]) {
    _reporterPath = [reporterPath copy];
    _outputPath = [outputPath copy];
  }
  return self;
}


- (NSFileHandle *)_fileHandleForOutputPath:(NSString *)outputPath
                                     error:(NSString **)error
{
  NSFileManager *fileManager = [NSFileManager defaultManager];

  NSString *basePath = [outputPath stringByDeletingLastPathComponent];

  if ([basePath length] > 0) {
    BOOL isDirectory;
    BOOL exists = [fileManager fileExistsAtPath:basePath isDirectory:&isDirectory];
    if (!exists) {
      if (![fileManager createDirectoryAtPath:basePath
                  withIntermediateDirectories:YES
                                   attributes:nil
                                        error:nil]) {
        *error = [NSString stringWithFormat:@"Failed to create folder at '%@'.",
                  basePath];
        return nil;
      }
    }
  }

  if (![fileManager createFileAtPath:outputPath contents:nil attributes:nil]) {
    *error = [NSString stringWithFormat:@"Failed to create file at '%@'.",
              outputPath];
    return nil;
  }

  return [NSFileHandle fileHandleForWritingAtPath:outputPath];
}

- (BOOL)openWithStandardOutput:(NSFileHandle *)standardOutput
                 standardError:(NSFileHandle *)standardError
                         error:(NSString **)error
{
  _standardOutput = standardOutput;
  _standardError = standardError;

  NSFileHandle *outputHandle = nil;

  if ([_outputPath isEqualToString:@"-"]) {
    outputHandle = standardOutput;
  } else {
    outputHandle = [self _fileHandleForOutputPath:_outputPath error:error];

    if (outputHandle == nil) {
      return NO;
    }

    _outputPathIsFile = YES;
  }

  _pipe = [NSPipe pipe];

  // Don't generate a SIGPIPE if the we try to write() to this pipe and the
  // process has already died.
  NSAssert(fcntl([[_pipe fileHandleForWriting] fileDescriptor], F_SETNOSIGPIPE, 1) != -1,
           @"fcntl() failed: %s", strerror(errno));


  // Make sure we get a REAL task when running under test!  If FakeTaskManager
  // is enabled, then we'd normally get a `FakeTask` instance when we call
  // `+[NSTask alloc]`.
  _task = CreateConcreteTaskInSameProcessGroup();

  [_task setLaunchPath:_reporterPath];
  [_task setArguments:@[]];
  [_task setStandardInput:_pipe];
  [_task setStandardOutput:outputHandle];

  @try {
    LaunchTaskAndMaybeLogCommand(_task, @"spawning reporter task");
  } @catch (NSException *ex) {
    // Launch will fail if process doesn't exist.
    *error = [NSString stringWithFormat:@"Failed to launch reporter process %@: %@",
              _reporterPath,
              [ex reason]];
    return NO;
  }

  _wasOpened = YES;
  return YES;
}

- (void)close
{
  NSAssert(_wasOpened, @"Can't close without opening first.");

  if (_wasClosed) {
    return;
  }

  // Close pipe so the reporter gets an EOF, and can terminate.
  [[_pipe fileHandleForWriting] closeFile];

  [_task waitUntilExit];

  // If we opened a file to store reporter output, make sure our handle is
  // closed.
  if (_outputPathIsFile) {
    [[_task standardOutput] closeFile];
  }

  _wasClosed = YES;
}

- (void)publishDataForEvent:(NSData *)data
{
  NSAssert(_wasOpened, @"Can't publish without opening first.");

  if (_wasClosed) {
    return;
  }

  NSMutableData *buffer = [[NSMutableData alloc] initWithCapacity:[data length] + 1];
  [buffer appendData:data];
  [buffer appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];

  int fd = [[_pipe fileHandleForWriting] fileDescriptor];

  NSUInteger bytesWritten = 0;
  NSUInteger bufferLength = [buffer length];
  const uint8_t *bufferPtr = [buffer bytes];

  while (bytesWritten < bufferLength) {
    size_t result = write(fd, bufferPtr + bytesWritten, (bufferLength - bytesWritten));

    if (result == -1) {
      if (errno == ESRCH || errno == EPIPE) {
        [self close];
        [_standardError printString:
         @"ERROR: Reporter '%@' exited prematurely with status (%d).\n",
         [_reporterPath lastPathComponent],
         [_task terminationStatus]];
        break;
      } else {
        NSAssert(NO,
                 @"Failed while write()'ing to the reporter's pipe: %s (%d)",
                 strerror(errno), errno);
      }
    } else {
      bytesWritten += result;
    }
  }

}

@end
