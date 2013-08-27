
#import <Foundation/Foundation.h>

#import "Options.h"

@interface Options (Testing)

/**
 * Returns an Options object, initialized with the given arguments via
 * consumeArguments:.  Throws an exception if options do not parse.
 */
+ (Options *)optionsFrom:(NSArray *)arguments;

/**
 * Throws an exception if validateReporterOptions: fails.
 */
- (Options *)assertReporterOptionsValidate;

/**
 * Throws exception if reporter validation doesn't fail with
 * the given message.
 */
- (void)assertReporterOptionsFailToValidateWithError:(NSString *)message;

/**
 * Asserts that options fail validateOptions: with a given error.
 */
- (void)assertOptionsFailToValidateWithError:(NSString *)message;

/**
 * Asserts that options fail validateOptions: with a given error.
 * A fake XcodeSubjectInfo is given to validateOptions: populated
 * with build settings from the given path.
 */
- (void)assertOptionsFailToValidateWithError:(NSString *)message
                   withBuildSettingsFromFile:(NSString *)path;

/**
 * Assert that validation passes.  A fake XcodeSubjectInfo is given to
 * validateOptions: populated with build settings from the given path.
 */
- (Options *)assertOptionsValidateWithBuildSettingsFromFile:(NSString *)path;

@end
