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

#import "FakeTask.h"

@implementation FakeTask

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus
                standardOutputPath:(NSString *)standardOutputPath
                 standardErrorPath:(NSString *)standardErrorPath
{
  FakeTask *task = [[[FakeTask alloc] init] autorelease];
  task->_fakeExitStatus = exitStatus;
  task->_fakeStandardOutputPath = [standardOutputPath retain];
  task->_fakeStandardErrorPath = [standardErrorPath retain];
  return task;
}

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus
{
  return [self fakeTaskWithExitStatus:exitStatus standardOutputPath:nil standardErrorPath:nil];
}

- (void)dealloc
{
  [_fakeStandardOutputPath release];
  [_fakeStandardErrorPath release];

  [_launchPath release];
  [_arguments release];
  [_environment release];
  [_standardOutput release];
  [_standardError release];
  [super dealloc];
}

- (void)launch
{
  NSMutableString *command = [NSMutableString string];

  if (_fakeStandardOutputPath) {
    [command appendFormat:@"cat \"%@\" > /dev/stdout;", _fakeStandardOutputPath];
  }

  if (_fakeStandardErrorPath) {
    [command appendFormat:@"cat \"%@\" > /dev/stderr;", _fakeStandardErrorPath];
  }

  [command appendFormat:@"exit %d", _fakeExitStatus];

  NSTask *realTask = [[[NSTask alloc] init] autorelease];
  [realTask setLaunchPath:@"/bin/bash"];
  [realTask setArguments:@[@"-c", command]];
  [realTask setEnvironment:@{}];

  [realTask setStandardOutput:([self standardOutput] ?: [NSFileHandle fileHandleWithNullDevice])];
  [realTask setStandardError:([self standardError] ?: [NSFileHandle fileHandleWithNullDevice])];

  [realTask launch];

  [self setIsRunning:YES];
  [realTask waitUntilExit];
  [self setTerminationStatus:[realTask terminationStatus]];
  [self setIsRunning:NO];
}

- (void)waitUntilExit
{
  // no-op
}

@end
