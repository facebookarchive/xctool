
#import <Foundation/Foundation.h>
#import "Action.h"
#import "XcodeTool.h"

@interface TestUtil : NSObject

+ (Options *)optionsFromArgumentList:(NSArray *)argumentList;

+ (Options *)validatedOptionsFromArgumentList:(NSArray *)argumentList;

+ (void)assertThatOptionsValidationWithArgumentList:(NSArray *)argumentList failsWithMessage:(NSString *)message;

+ (NSDictionary *)runWithFakeStreams:(XcodeTool *)tool;

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus
                    standardOutput:(NSString *)standardOutput
                     standardError:(NSString *)standardError;

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus;

+ (NSTask *)fakeTask;

@end
