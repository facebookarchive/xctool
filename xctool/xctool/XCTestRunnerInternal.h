
#import "XCTestRunner.h"

@interface XCTestRunner (Internal)

/**
 Subclasses of XCTestRunner implement this method to actually
 run the tests.
 */
- (void)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock
                   startupError:(NSString **)startupError
                    otherErrors:(NSString **)otherErrors;

@end
