
#import "Fakes.h"

@implementation FakeTask

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus
                standardOutputPath:(NSString *)standardOutputPath
                 standardErrorPath:(NSString *)standardErrorPath
{
  NSString *standardOutput = [NSString stringWithContentsOfFile:standardOutputPath encoding:NSUTF8StringEncoding error:nil];
  NSString *standardError = [NSString stringWithContentsOfFile:standardErrorPath encoding:NSUTF8StringEncoding error:nil];
  FakeTask *fakeTask = [[[FakeTask alloc] init] autorelease];

  fakeTask.onLaunchBlock = ^{
    // pretend that launch closes standardOutput / standardError pipes
    NSTask *task = fakeTask;

    NSFileHandle *(^fileHandleForWriting)(id) = ^(id pipeOrFileHandle) {
      if ([pipeOrFileHandle isKindOfClass:[NSPipe class]]) {
        return [pipeOrFileHandle fileHandleForWriting];
      } else {
        return (NSFileHandle *)pipeOrFileHandle;
      }
    };

    if (standardOutput) {
      [fileHandleForWriting([task standardOutput]) writeData:[standardOutput dataUsingEncoding:NSUTF8StringEncoding]];
    }

    if (standardError) {
      [fileHandleForWriting([task standardOutput]) writeData:[standardError dataUsingEncoding:NSUTF8StringEncoding]];
    }

    [fileHandleForWriting([task standardOutput]) closeFile];
    [fileHandleForWriting([task standardError]) closeFile];
  };

  fakeTask.terminationStatus = exitStatus;
  
  return fakeTask;
}

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus
{
  return [self fakeTaskWithExitStatus:exitStatus standardOutputPath:nil standardErrorPath:nil];
}

- (void)dealloc
{
  [_onLaunchBlock release];
  [_launchPath release];
  [super dealloc];
}

- (void)launch
{
  self.isRunning = YES;
  if (_onLaunchBlock) {
    _onLaunchBlock();
  }
  
  [self performSelector:@selector(finishAfterDelay) withObject:nil afterDelay:0.0];
}

- (void)finishAfterDelay
{
  self.isRunning = NO;
  [[NSNotificationCenter defaultCenter] postNotificationName:NSTaskDidTerminateNotification object:self];
  
  if ([[self standardOutput] isKindOfClass:[NSPipe pipe]]) {
    [[[self standardOutput] fileHandleForWriting] closeFile];
  }
  
  if ([[self standardError] isKindOfClass:[NSPipe pipe]]) {
    [[[self standardError] fileHandleForWriting] closeFile];
  }
  
  if (_isWaitingUntilExit) {
    CFRunLoopStop(CFRunLoopGetCurrent());
  }
}

- (void)waitUntilExit
{
  _isWaitingUntilExit = YES;
  while (self.isRunning) {
    CFRunLoopRun();
  }
  _isWaitingUntilExit = NO;
}

@end