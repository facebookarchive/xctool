
#import <Foundation/Foundation.h>

@interface FakeTask : NSTask
{
  BOOL _isWaitingUntilExit;
}

@property (nonatomic, copy) void (^onLaunchBlock)(void);
@property (nonatomic, retain) NSString *launchPath;
@property (nonatomic, retain) NSArray *arguments;
@property (nonatomic, retain) NSDictionary *environment;
@property (nonatomic, retain) id standardOutput;
@property (nonatomic, retain) id standardError;
@property (nonatomic, assign) int terminationStatus;
@property (nonatomic, assign) BOOL isRunning;

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus
                standardOutputPath:(NSString *)standardOutputPath
                 standardErrorPath:(NSString *)standardErrorPath;

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus;


@end
