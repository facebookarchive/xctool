#import <Cocoa/Cocoa.h>

/*
 * File: /Developer/Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks/iPhoneSimulatorRemoteClient.framework/Versions/A/iPhoneSimulatorRemoteClient
 * Arch: Intel 80x86 (i386)
 *       Current version: 12.0.0, Compatibility version: 1.0.0
 */

@class DTiPhoneSimulatorSession;

@protocol DTiPhoneSimulatorSessionDelegate

- (void) session: (DTiPhoneSimulatorSession *) session didEndWithError: (NSError *) error;
- (void) session: (DTiPhoneSimulatorSession *) session didStart: (BOOL) started withError: (NSError *) error;

@end

/*
 * File: /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks/DVTiPhoneSimulatorRemoteClient.framework/Versions/A/DVTiPhoneSimulatorRemoteClient
 * UUID: 79CF7E01-7773-3D7E-B5B5-3D085F64158D
 * Arch: Intel x86-64 (x86_64)
 *       Current version: 12.0.0, Compatibility version: 1.0.0
 *       Minimum Mac OS X version: 10.8.0
 *
 *       Objective-C Garbage Collection: Unsupported
 *       Run path: @loader_path/../../../../PrivateFrameworks/
 *               = /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks
 */

@class DTiPhoneSimulatorApplicationSpecifier;
@class DTiPhoneSimulatorSessionConfig;
@class DTiPhoneSimulatorSystemRoot;
typedef void DVTDispatchLock;
typedef void DVTTask;
typedef void DVTConfinementServiceConnection;

@interface DVTiPhoneSimulatorMessenger : NSObject
{
  DTiPhoneSimulatorSession *_session;
  id _readyMessageHandler;
  id _runningMessageHandler;
  id _appDidLaunchMessageHandler;
  id _appDidQuitMessageHandler;
  id _appPIDExitedMessageHandler;
  id _toolDidLaunchMessageHandler;
}

+ (id)messengerForSession:(id)arg1 withConnection:(id)arg2;
+ (id)messengerForSession:(id)arg1;
@property(copy, nonatomic) id toolDidLaunchMessageHandler; // @synthesize toolDidLaunchMessageHandler=_toolDidLaunchMessageHandler;
@property(copy, nonatomic) id appPIDExitedMessageHandler; // @synthesize appPIDExitedMessageHandler=_appPIDExitedMessageHandler;
@property(copy, nonatomic) id appDidQuitMessageHandler; // @synthesize appDidQuitMessageHandler=_appDidQuitMessageHandler;
@property(copy, nonatomic) id appDidLaunchMessageHandler; // @synthesize appDidLaunchMessageHandler=_appDidLaunchMessageHandler;
@property(copy, nonatomic) id runningMessageHandler; // @synthesize runningMessageHandler=_runningMessageHandler;
@property(copy, nonatomic) id readyMessageHandler; // @synthesize readyMessageHandler=_readyMessageHandler;
@property(readonly) DTiPhoneSimulatorSession *session; // @synthesize session=_session;
- (void)doUbiquityFetchEvent;
- (void)doFetchEventForPID:(int)arg1;
- (void)backgroundAllApps:(int)arg1;
- (void)startSimulatorToolSessionWithParameters:(id)arg1;
- (void)stopSimulatingLocation;
- (void)startSimulatingLocationWithLatitude:(id)arg1 longitute:(id)arg2;
- (void)endSimulatorSessionWithPID:(int)arg1;
- (void)startSimulatorSessionWithRequestInfo:(id)arg1;
- (void)clearAllMessageHandlers;
- (void)waitPID:(int)arg1 withAppPIDExitedMessagedHandler:(id)arg2;
- (void)disconnectFromService;
- (BOOL)connectToServiceWithSessionOnLaunch:(BOOL)arg1 simulatorPID:(int *)arg2 error:(id *)arg3;
- (id)initWithSession:(id)arg1;

@end

@interface DVTiPhoneSimulatorLocalMessenger : DVTiPhoneSimulatorMessenger
{
  BOOL _appTerminationMessageSent;
  struct dispatch_source_s *_pidDispatchSource;
  DVTTask *_simTask;
}

- (void)doUbiquityFetchEvent;
- (void)doFetchEventForPID:(int)arg1;
- (void)backgroundAllApps:(int)arg1;
- (void)_handleSimulatorToolDidLaunchMessage:(id)arg1;
- (void)setToolDidLaunchMessageHandler:(id)arg1;
- (void)waitPID:(int)arg1 withAppPIDExitedMessagedHandler:(id)arg2;
- (void)_handleSimulatorAppDidQuitMessage:(id)arg1;
- (void)setAppDidQuitMessageHandler:(id)arg1;
- (void)_handleSimulatorAppDidLaunchMessage:(id)arg1;
- (void)setAppDidLaunchMessageHandler:(id)arg1;
- (void)_handleSimulatorRunningMessage:(id)arg1;
- (void)setRunningMessageHandler:(id)arg1;
- (void)_handleSimulatorReadyMessage:(id)arg1;
- (void)setReadyMessageHandler:(id)arg1;
- (void)startSimulatorToolSessionWithParameters:(id)arg1;
- (void)stopSimulatingLocation;
- (void)startSimulatingLocationWithLatitude:(id)arg1 longitute:(id)arg2;
- (void)endSimulatorSessionWithPID:(int)arg1;
- (void)startSimulatorSessionWithRequestInfo:(id)arg1;
- (void)clearAllMessageHandlers;
- (void)disconnectFromService;
- (BOOL)connectToServiceWithSessionOnLaunch:(BOOL)arg1 simulatorPID:(int *)arg2 error:(id *)arg3;
- (void)_enableObserver:(BOOL)arg1 forName:(id)arg2 selector:(SEL)arg3;

@end


@interface DVTiPhoneSimulatorRemoteMessenger : DVTiPhoneSimulatorMessenger
{
  unsigned long long _commandTag;
  struct dispatch_queue_s *_responseQueue;
  DVTDispatchLock *_awaitingLock;
  NSMutableDictionary *_awaitingSemaphores;
  NSMutableDictionary *_awaitingResponses;
  NSMutableSet *_waitingAppPIDs;
  DVTConfinementServiceConnection *_connection;
}

@property(readonly) DVTConfinementServiceConnection *connection; // @synthesize connection=_connection;
- (void)handleNotificationResponse:(id)arg1;
- (void)waitPID:(int)arg1 withAppPIDExitedMessagedHandler:(id)arg2;
- (void)startSimulatorToolSessionWithParameters:(id)arg1;
- (void)stopSimulatingLocation;
- (void)startSimulatingLocationWithLatitude:(id)arg1 longitute:(id)arg2;
- (void)endSimulatorSessionWithPID:(int)arg1;
- (void)startSimulatorSessionWithRequestInfo:(id)arg1;
- (void)disconnectFromService;
- (BOOL)connectToServiceWithSessionOnLaunch:(BOOL)arg1 simulatorPID:(int *)arg2 error:(id *)arg3;
- (BOOL)sendTaggedRequest:(id)arg1 awaitingResponse:(id *)arg2 error:(id *)arg3;
- (id)nextCommandTag;
- (id)awaitResponseWithTag:(id)arg1 error:(id *)arg2;
- (void)enqueueResponse:(id)arg1 withTag:(id)arg2 error:(id)arg3;
- (BOOL)sendRequest:(id)arg1 withTag:(id)arg2 error:(id *)arg3;
- (void)dealloc;
- (id)initWithSession:(id)arg1 connection:(id)arg2;

@end

@interface DTiPhoneSimulatorSession : NSObject
{
  int _simulatedApplicationPID;
  int _simulatorPID;
  NSString *_uuid;
  id <DTiPhoneSimulatorSessionDelegate> _delegate;
  NSString *_simulatedAppPath;
  long long _sessionLifecycleProgress;
  NSTimer *_timeoutTimer;
  DTiPhoneSimulatorSessionConfig *_sessionConfig;
  DVTiPhoneSimulatorMessenger *_messenger;
}

@property(retain) DVTiPhoneSimulatorMessenger *messenger; // @synthesize messenger=_messenger;
@property(copy, nonatomic) DTiPhoneSimulatorSessionConfig *sessionConfig; // @synthesize sessionConfig=_sessionConfig;
@property(retain, nonatomic) NSTimer *timeoutTimer; // @synthesize timeoutTimer=_timeoutTimer;
@property(nonatomic) long long sessionLifecycleProgress; // @synthesize sessionLifecycleProgress=_sessionLifecycleProgress;
@property int simulatorPID; // @synthesize simulatorPID=_simulatorPID;
@property(copy) NSString *simulatedAppPath; // @synthesize simulatedAppPath=_simulatedAppPath;
@property int simulatedApplicationPID; // @synthesize simulatedApplicationPID=_simulatedApplicationPID;
@property(retain, nonatomic) id <DTiPhoneSimulatorSessionDelegate> delegate; // @synthesize delegate=_delegate;
@property(copy, nonatomic) NSString *uuid; // @synthesize uuid=_uuid;
- (void)doUbiquityFetchEvent;
- (void)doFetchEventForPID:(int)arg1;
- (void)backgroundAllApps:(int)arg1;
- (id)_invalidConfigError;
- (void)_endSimulatorSession;
- (void)_callDelegateResponseFromSessionEndedInfo:(id)arg1;
- (void)_callDelegateResponseFromSessionStartedInfo:(id)arg1;
- (id)_sessionStartRequestInfoFromConfig:(id)arg1 withError:(id *)arg2;
- (BOOL)_startToolSessionInSimulatorWithError:(id *)arg1;
- (BOOL)_startApplicationSessionInSimulatorWithError:(id *)arg1;
- (BOOL)_startBasicSessionInSimulatorWithError:(id *)arg1;
- (BOOL)_startSessionInSimulatorWithError:(id *)arg1;
- (BOOL)_handleSessionEndedInSimulator:(id)arg1 notification:(id)arg2;
- (void)_handleSessionStartedWithSim:(id)arg1;
- (void)_handleSessionStartedInSimulator:(id)arg1;
- (void)_handleSimulatorReadyMessage:(id)arg1;
- (void)_timeoutElapsed:(id)arg1;
- (BOOL)attachedToTargetWithConfig:(id)arg1 error:(id *)arg2;
- (void)stopLocationSimulation;
- (void)simulateLocationWithLatitude:(id)arg1 longitude:(id)arg2;
- (void)requestEndWithTimeout:(double)arg1;
- (BOOL)requestStartWithConfig:(id)arg1 timeout:(double)arg2 error:(id *)arg3;
- (BOOL)_setUpSimulatorMessengerWithConfig:(id)arg1 error:(id *)arg2;
- (id)description;
- (void)dealloc;
- (id)init;

@end

@interface DTiPhoneSimulatorSessionConfig : NSObject <NSCopying>
{
  BOOL _launchForBackgroundFetch;
  BOOL _simulatedApplicationShouldWaitForDebugger;
  NSString *_localizedClientName;
  DTiPhoneSimulatorSystemRoot *_simulatedSystemRoot;
  NSString *_simulatedDeviceInfoName;
  NSNumber *_simulatedDeviceFamily;
  NSString *_simulatedArchitecture;
  NSNumber *_simulatedDisplayHeight;
  NSNumber *_simulatedDisplayScale;
  DTiPhoneSimulatorApplicationSpecifier *_applicationToSimulateOnStart;
  NSNumber *_pid;
  NSArray *_simulatedApplicationLaunchArgs;
  NSDictionary *_simulatedApplicationLaunchEnvironment;
  NSString *_simulatedApplicationStdOutPath;
  NSString *_simulatedApplicationStdErrPath;
  NSFileHandle *_stdinFileHandle;
  NSFileHandle *_stdoutFileHandle;
  NSFileHandle *_stderrFileHandle;
  id _confinementService;
}

+ (id)displayNameForDeviceFamily:(id)arg1;
@property(retain) id confinementService; // @synthesize confinementService=_confinementService;
@property(retain) NSFileHandle *stderrFileHandle; // @synthesize stderrFileHandle=_stderrFileHandle;
@property(retain) NSFileHandle *stdoutFileHandle; // @synthesize stdoutFileHandle=_stdoutFileHandle;
@property(retain) NSFileHandle *stdinFileHandle; // @synthesize stdinFileHandle=_stdinFileHandle;
@property(copy) NSString *simulatedApplicationStdErrPath; // @synthesize simulatedApplicationStdErrPath=_simulatedApplicationStdErrPath;
@property(copy) NSString *simulatedApplicationStdOutPath; // @synthesize simulatedApplicationStdOutPath=_simulatedApplicationStdOutPath;
@property BOOL simulatedApplicationShouldWaitForDebugger; // @synthesize simulatedApplicationShouldWaitForDebugger=_simulatedApplicationShouldWaitForDebugger;
@property(copy) NSDictionary *simulatedApplicationLaunchEnvironment; // @synthesize simulatedApplicationLaunchEnvironment=_simulatedApplicationLaunchEnvironment;
@property(copy) NSArray *simulatedApplicationLaunchArgs; // @synthesize simulatedApplicationLaunchArgs=_simulatedApplicationLaunchArgs;
@property(copy) NSNumber *pid; // @synthesize pid=_pid;
@property(copy) DTiPhoneSimulatorApplicationSpecifier *applicationToSimulateOnStart; // @synthesize applicationToSimulateOnStart=_applicationToSimulateOnStart;
@property(copy) NSNumber *simulatedDisplayScale; // @synthesize simulatedDisplayScale=_simulatedDisplayScale;
@property(copy) NSNumber *simulatedDisplayHeight; // @synthesize simulatedDisplayHeight=_simulatedDisplayHeight;
@property(copy) NSString *simulatedArchitecture; // @synthesize simulatedArchitecture=_simulatedArchitecture;
@property(copy) NSNumber *simulatedDeviceFamily; // @synthesize simulatedDeviceFamily=_simulatedDeviceFamily;
@property(retain) NSString *simulatedDeviceInfoName; // @synthesize simulatedDeviceInfoName=_simulatedDeviceInfoName;
@property(copy) DTiPhoneSimulatorSystemRoot *simulatedSystemRoot; // @synthesize simulatedSystemRoot=_simulatedSystemRoot;
@property(copy) NSString *localizedClientName; // @synthesize localizedClientName=_localizedClientName;
@property BOOL launchForBackgroundFetch; // @synthesize launchForBackgroundFetch=_launchForBackgroundFetch;
- (id)description;
- (id)copyWithZone:(struct _NSZone *)arg1;
- (id)init;

@end

@interface DTiPhoneSimulatorSystemRoot : NSObject <NSCopying>
{
  NSString *sdkRootPath;
  NSString *sdkVersion;
  NSString *sdkDisplayName;
}

+ (id)rootWithSDKVersion:(id)arg1;
+ (id)rootWithSDKPath:(id)arg1;
+ (id)defaultRoot;
+ (id)knownRoots;
+ (void)initialize;
@property(copy) NSString *sdkDisplayName; // @synthesize sdkDisplayName;
@property(copy) NSString *sdkVersion; // @synthesize sdkVersion;
@property(copy) NSString *sdkRootPath; // @synthesize sdkRootPath;
- (id)description;
- (long long)compare:(id)arg1;
- (id)copyWithZone:(struct _NSZone *)arg1;
- (BOOL)isEqual:(id)arg1;
- (id)initWithSDKPath:(id)arg1;

@end

@interface DTiPhoneSimulatorApplicationSpecifier : NSObject <NSCopying>
{
  NSString *appPath;
  NSString *bundleID;
  NSString *toolPath;
}

+ (id)specifierWithToolPath:(id)arg1;
+ (id)specifierWithApplicationBundleIdentifier:(id)arg1;
+ (id)specifierWithApplicationPath:(id)arg1;
@property(copy, nonatomic) NSString *toolPath; // @synthesize toolPath;
@property(copy, nonatomic) NSString *bundleID; // @synthesize bundleID;
@property(copy, nonatomic) NSString *appPath; // @synthesize appPath;
- (id)description;
- (id)copyWithZone:(struct _NSZone *)arg1;

@end
