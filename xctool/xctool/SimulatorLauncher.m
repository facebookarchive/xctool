
#import "SimulatorLauncher.h"

@implementation SimulatorLauncher

- (id)initWithSessionConfig:(DTiPhoneSimulatorSessionConfig *)sessionConfig
{
  if (self = [super init]) {
    _session = [[DTiPhoneSimulatorSession alloc] init];
    [_session setSessionConfig:sessionConfig];
    [_session setDelegate:self];
  }
  return self;
}

- (void)dealloc
{
  [_session release];
  [_launchError release];
  [_didEndWithError release];
  [super dealloc];
}

- (BOOL)launchAndWaitForExit
{
  NSError *error = nil;
  if (![_session requestStartWithConfig:[_session sessionConfig] timeout:30 error:&error]) {
    self.launchError = error;
    return NO;
  }

  while (!_didQuit && !_didFailToStart) {
    CFRunLoopRun();
  }

  return _didStart;
}

- (void)session:(DTiPhoneSimulatorSession *)session didEndWithError:(NSError *)error
{
  if (error) {
    _didEndWithError = [error retain];
  }
  _didQuit = YES;

  CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)session:(DTiPhoneSimulatorSession *)session didStart:(BOOL)started withError:(NSError *)error
{
  if (started) {
    _didStart = YES;
  } else {
    self.launchError = error;
    _didFailToStart = YES;
  }

  CFRunLoopStop(CFRunLoopGetCurrent());
}

@end
