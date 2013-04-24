
#import <Foundation/Foundation.h>

#import "Action.h"
#import "XCTool.h"

@interface TestUtil : NSObject

+ (Options *)optionsFromArgumentList:(NSArray *)argumentList;

+ (Options *)validatedReporterOptionsFromArgumentList:(NSArray *)argumentList;

+ (void)assertThatReporterOptionsValidateWithArgumentList:(NSArray *)argumentList;
+ (void)assertThatReporterOptionsValidateWithArgumentList:(NSArray *)argumentList failsWithMessage:(NSString *)message;

+ (Options *)validatedOptionsFromArgumentList:(NSArray *)argumentList;

+ (void)assertThatOptionsValidateWithArgumentList:(NSArray *)argumentList;
+ (void)assertThatOptionsValidateWithArgumentList:(NSArray *)argumentList failsWithMessage:(NSString *)message;

+ (NSDictionary *)runWithFakeStreams:(XCTool *)tool;

@end
