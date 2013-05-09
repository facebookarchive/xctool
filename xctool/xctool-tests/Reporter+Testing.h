
#import "Reporter.h"

@interface Reporter (Testing)

/**
 * Consumes json-stream events from a file and returns to you what the
 * reporter would have written to its file handle.
 */
+ (NSData *)outputDataWithEventsFromFile:(NSString *)path
                                 options:(Options *)options;

@end
