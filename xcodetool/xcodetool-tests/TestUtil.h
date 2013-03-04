
#import <Foundation/Foundation.h>
#import "Action.h"
#import "Options.h"
#import "FBXcodeTool.h"

@interface TestUtil : NSObject

//+ (Action *)actionWithArguments:(NSArray *)arguments;
//
//+ (Action *)validatedActionWithArguments:(NSArray *)arguments;
//
//+ (void)assertThatValidationWithArgumentList:(NSArray *)argumentList
//                            failsWithMessage:(NSString *)message;
//
//+ (void)assertThatValidationPassesWithArgumentList:(NSArray *)argumentList;

+ (Options *)optionsFromArgumentList:(NSArray *)argumentList;

+ (Options *)validatedOptionsFromArgumentList:(NSArray *)argumentList;

//+ (void)assertThatOptionsParseArgumentList:(NSArray *)argumentList failsWithMessage:(NSString *)message;
//
+ (void)assertThatOptionsValidationWithArgumentList:(NSArray *)argumentList failsWithMessage:(NSString *)message;
//
//+ (void)assertThatOptionsValidationPassesWithArgumentList:(NSArray *)argumentList;

+ (NSDictionary *)runWithFakeStreams:(FBXcodeTool *)tool;

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus
                    standardOutput:(NSString *)standardOutput
                     standardError:(NSString *)standardError;

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus;

+ (NSTask *)fakeTask;

@end
