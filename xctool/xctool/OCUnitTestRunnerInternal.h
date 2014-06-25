
#import "OCUnitTestRunner.h"

@interface OCUnitTestRunner (Internal)

/**
 Subclasses of OCUnitTestRunner implement this method to actually
 run the tests.
 */
- (void)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock
                   startupError:(NSString **)startupError
                    otherErrors:(NSString **)otherErrors;

@end
