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

@property(copy, nonatomic) id toolDidLaunchMessageHandler;
@property(copy, nonatomic) id appPIDExitedMessageHandler;
@property(copy, nonatomic) id appDidQuitMessageHandler;
@property(copy, nonatomic) id appDidLaunchMessageHandler;
@property(copy, nonatomic) id runningMessageHandler;
@property(copy, nonatomic) id readyMessageHandler;
@property(readonly) DTiPhoneSimulatorSession *session;

+ (instancetype)messengerForSession:(id)arg1 withConnection:(id)arg2;
+ (instancetype)messengerForSession:(id)arg1;

- (instancetype)initWithSession:(id)arg1;
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
}

@property(readonly) DVTConfinementServiceConnection *connection;
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
- (instancetype)initWithSession:(id)arg1 connection:(id)arg2;

@end

@interface DTiPhoneSimulatorSession : NSObject

@property(retain) DVTiPhoneSimulatorMessenger *messenger;
@property(copy, nonatomic) DTiPhoneSimulatorSessionConfig *sessionConfig;
@property(retain, nonatomic) NSTimer *timeoutTimer;
@property(nonatomic) long long sessionLifecycleProgress;
@property int simulatorPID;
@property(copy) NSString *simulatedAppPath;
@property int simulatedApplicationPID;
@property(retain, nonatomic) id <DTiPhoneSimulatorSessionDelegate> delegate;
@property(copy, nonatomic) NSString *uuid;

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

@end

@class SimDevice, SimRuntime;

@interface DTiPhoneSimulatorSessionConfig : NSObject <NSCopying>

+ (id)displayNameForDeviceFamily:(id)arg1;

@property(copy) DTiPhoneSimulatorApplicationSpecifier *applicationToSimulateOnStart;
@property(retain) id confinementService;
@property(retain) SimDevice *device;
@property(retain) SimRuntime *runtime;
@property BOOL launchForBackgroundFetch;
@property(copy) NSString *localizedClientName;
@property(copy) NSNumber *pid;
@property(copy) NSArray *simulatedApplicationLaunchArgs;
@property(copy) NSDictionary *simulatedApplicationLaunchEnvironment;
@property BOOL simulatedApplicationShouldWaitForDebugger;
@property(copy) NSString *simulatedApplicationStdErrPath;
@property(copy) NSString *simulatedApplicationStdOutPath;
@property(copy) NSString *simulatedArchitecture;
@property(copy) NSNumber *simulatedDeviceFamily;
@property(retain) NSString *simulatedDeviceInfoName;
@property(copy) NSNumber *simulatedDisplayHeight;
@property(copy) NSNumber *simulatedDisplayScale;
@property(copy) DTiPhoneSimulatorSystemRoot *simulatedSystemRoot;
@property(retain) NSFileHandle *stderrFileHandle;
@property(retain) NSFileHandle *stdinFileHandle;
@property(retain) NSFileHandle *stdoutFileHandle;

@end

@interface DTiPhoneSimulatorSystemRoot : NSObject <NSCopying>

@property(readonly) SimRuntime *runtime;
@property(copy) NSString *sdkDisplayName;
@property(copy) NSString *sdkVersion;
@property(copy) NSString *sdkRootPath;

+ (instancetype)rootWithSimRuntimeStub:(id)arg1;
+ (instancetype)rootWithSDKVersion:(id)arg1;
+ (instancetype)rootWithSDKPath:(id)arg1;
+ (DTiPhoneSimulatorSystemRoot *)defaultRoot;
+ (id)knownRoots;

- (long long)compare:(id)arg1;
- (instancetype)initWithSDKPath:(id)arg1;

@end

@interface DTiPhoneSimulatorApplicationSpecifier : NSObject <NSCopying>

@property(copy, nonatomic) NSString *toolPath;
@property(copy, nonatomic) NSString *bundleID;
@property(copy, nonatomic) NSString *appPath;

+ (instancetype)specifierWithToolPath:(id)arg1;
+ (instancetype)specifierWithApplicationBundleIdentifier:(id)arg1;
+ (instancetype)specifierWithApplicationPath:(id)arg1;

@end
