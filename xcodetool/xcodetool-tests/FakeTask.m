
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
