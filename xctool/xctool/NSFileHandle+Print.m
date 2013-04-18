
#import "NSFileHandle+Print.h"

@implementation NSFileHandle (Print)
- (void)printString:(NSString *)format, ... {
  va_list args;
  va_start(args, format);
  NSString *str = [[[NSString alloc] initWithFormat:format arguments:args] autorelease];
  [self writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
  va_end(args);
}
@end

