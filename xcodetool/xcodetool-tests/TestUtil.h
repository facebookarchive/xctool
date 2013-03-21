
#import <Foundation/Foundation.h>
#import "Action.h"
#import "XcodeTool.h"

@interface TestUtil : NSObject

+ (ImplicitAction *)optionsFromArgumentList:(NSArray *)argumentList;

+ (ImplicitAction *)validatedOptionsFromArgumentList:(NSArray *)argumentList;

+ (void)assertThatOptionsValidationWithArgumentList:(NSArray *)argumentList failsWithMessage:(NSString *)message;

+ (NSDictionary *)runWithFakeStreams:(XcodeTool *)tool;

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus
                    standardOutput:(NSString *)standardOutput
                     standardError:(NSString *)standardError;

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus;

+ (NSTask *)fakeTask;

@end
