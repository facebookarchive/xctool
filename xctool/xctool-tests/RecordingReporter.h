
#import "Reporter.h"

/**
 A Reporter that just records all events it receives.  Useful for writing tests.
 */
@interface RecordingReporter : Reporter
{
  NSMutableArray *_events;
}

- (NSArray *)events;

@end
