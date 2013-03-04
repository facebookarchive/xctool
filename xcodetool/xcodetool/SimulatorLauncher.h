
#import <Foundation/Foundation.h>
#import "iPhoneSimulatorRemoteClient.h"

@interface SimulatorLauncher : NSObject <DTiPhoneSimulatorSessionDelegate>
{
  BOOL _didQuit;
  BOOL _didFailToStart;
  BOOL _didStart;
  DTiPhoneSimulatorSession *_session;
  NSError *_didEndWithError;
}

@property (nonatomic, retain) NSError *launchError;

- (id)initWithSessionConfig:(DTiPhoneSimulatorSessionConfig *)sessionConfig;
- (BOOL)launch;
- (void)waitUntilAppExits;

@end