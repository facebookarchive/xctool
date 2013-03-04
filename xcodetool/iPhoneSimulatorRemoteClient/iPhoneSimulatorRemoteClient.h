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

@interface DTiPhoneSimulatorApplicationSpecifier : NSObject <NSCopying>
{
    NSString *_appPath;
    NSString *_bundleID;
}

+ (id) specifierWithApplicationPath: (NSString *) appPath;
+ (id) specifierWithApplicationBundleIdentifier: (NSString *) bundleID;
- (NSString *) bundleID;
- (void) setBundleID: (NSString *) bundleId;
- (NSString *) appPath;
- (void) setAppPath: (NSString *) appPath;

@end

@interface DTiPhoneSimulatorSystemRoot : NSObject <NSCopying>
{
    NSString *sdkRootPath;
    NSString *sdkVersion;
    NSString *sdkDisplayName;
}

+ (id) defaultRoot;

+ (id)rootWithSDKPath:(id)fp8;
+ (id)rootWithSDKVersion:(id)fp8;
+ (NSArray *) knownRoots;
- (id)initWithSDKPath:(id)fp8;
- (id)sdkDisplayName;
- (void)setSdkDisplayName:(id)fp8;
- (id)sdkVersion;
- (void)setSdkVersion:(id)fp8;
- (id)sdkRootPath;
- (void)setSdkRootPath:(id)fp8;

@end



@interface DTiPhoneSimulatorSessionConfig : NSObject <NSCopying>
{
    NSString *_localizedClientName;
    DTiPhoneSimulatorSystemRoot *_simulatedSystemRoot;
    DTiPhoneSimulatorApplicationSpecifier *_applicationToSimulateOnStart;
    NSArray *_simulatedApplicationLaunchArgs;
    NSDictionary *_simulatedApplicationLaunchEnvironment;
    BOOL _simulatedApplicationShouldWaitForDebugger;
    NSString *_simulatedApplicationStdOutPath;
    NSString *_simulatedApplicationStdErrPath;
}

- (id)simulatedApplicationStdErrPath;
- (void)setSimulatedApplicationStdErrPath:(id)fp8;
- (id)simulatedApplicationStdOutPath;
- (void)setSimulatedApplicationStdOutPath:(id)fp8;
- (id)simulatedApplicationLaunchEnvironment;
- (void)setSimulatedApplicationLaunchEnvironment:(id)fp8;
- (id)simulatedApplicationLaunchArgs;
- (void)setSimulatedApplicationLaunchArgs:(id)fp8;

- (DTiPhoneSimulatorApplicationSpecifier *) applicationToSimulateOnStart;
- (void) setApplicationToSimulateOnStart: (DTiPhoneSimulatorApplicationSpecifier *) appSpec;
- (DTiPhoneSimulatorSystemRoot *) simulatedSystemRoot;
- (void) setSimulatedSystemRoot: (DTiPhoneSimulatorSystemRoot *) simulatedSystemRoot;


- (BOOL) simulatedApplicationShouldWaitForDebugger;
- (void) setSimulatedApplicationShouldWaitForDebugger: (BOOL) waitForDebugger;

- (id)localizedClientName;
- (void)setLocalizedClientName:(id)fp8;

// Added in 3.2 to support iPad/iPhone device families
- (void)setSimulatedDeviceFamily:(NSNumber*)family;

@end


@interface DTiPhoneSimulatorSession : NSObject {
    NSString *_uuid;
    id <DTiPhoneSimulatorSessionDelegate> _delegate;
    NSNumber *_simulatedApplicationPID;
    int _sessionLifecycleProgress;
    NSTimer *_timeoutTimer;
    DTiPhoneSimulatorSessionConfig *_sessionConfig;
    struct ProcessSerialNumber _simulatorPSN;
}

- (BOOL) requestStartWithConfig: (DTiPhoneSimulatorSessionConfig *) config timeout: (NSTimeInterval) timeout error: (NSError **) outError;
- (void) requestEndWithTimeout: (NSTimeInterval) timeout;

- (id)sessionConfig;
- (void)setSessionConfig:(id)fp8;
- (id)timeoutTimer;
- (void)setTimeoutTimer:(id)fp8;
- (int)sessionLifecycleProgress;
- (void)setSessionLifecycleProgress:(int)fp8;
- (id)simulatedApplicationPID;
- (void)setSimulatedApplicationPID:(id)fp8;

- (id<DTiPhoneSimulatorSessionDelegate>) delegate;
- (void) setDelegate: (id<DTiPhoneSimulatorSessionDelegate>) delegate;

- (id)uuid;
- (void)setUuid:(id)fp8;

@end
