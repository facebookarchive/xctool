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

#import "ReporterTask.h"

#import <objc/message.h>

#import "XCToolUtil.h"


@implementation ReporterTask

- (instancetype)initWithReporterPath:(NSString *)reporterPath
                          outputPath:(NSString *)outputPath
{
  if (self = [super init]) {
    _reporterPath = [reporterPath retain];
    _outputPath = [outputPath retain];
  }
  return self;
}

- (void)dealloc
{
  [_reporterPath release];
  [_outputPath release];
  [_task release];
  [_pipe release];
  [super dealloc];
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
                         error:(NSString **)error
{
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

  _pipe = [[NSPipe pipe] retain];


  if (IsRunningUnderTest()) {
    // In tests, we swizzle +[NSTask alloc] to always return FakeTask's.  We can
    // still access the original 'allocWithZone:' selector, though.
    _task = objc_msgSend([NSTask class],
                         @selector(__NSTask_allocWithZone:),
                         NSDefaultMallocZone());
  } else {
    _task = [[NSTask alloc] init];
  }

  [_task setLaunchPath:_reporterPath];
  [_task setArguments:@[]];
  [_task setStandardInput:_pipe];
  [_task setStandardOutput:outputHandle];

  @try {
    [_task launch];
  } @catch (NSException *ex) {
    // Launch will fail if process doesn't exist.
    *error = [NSString stringWithFormat:@"Failed to launch reporter process: %@",
              [ex reason]];
    return NO;
  }

  return YES;
}

- (void)close
{
  // Close pipe so the reporter gets an EOF, and can terminate.
  [[_pipe fileHandleForWriting] closeFile];

  [_task waitUntilExit];

  // If we opened a file to store reporter output, make sure our handle is
  // closed.
  if (_outputPathIsFile) {
    [[_task standardOutput] closeFile];
  }
}

- (void)publishDataForEvent:(NSData *)data
{
  [[_pipe fileHandleForWriting] writeData:data];
  [[_pipe fileHandleForWriting] writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
}

@end
