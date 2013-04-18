
#import <Foundation/Foundation.h>

@interface NSFileHandle (Private)
- (void)printString:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
@end
