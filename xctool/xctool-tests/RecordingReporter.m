
#import "RecordingReporter.h"

@implementation RecordingReporter

- (id)init
{
  if (self = [super init]) {
    _events = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc
{
  [_events release];
  [super dealloc];
}

- (NSArray *)events
{
  return _events;
}

- (void)recordEvent:(NSDictionary *)event
{
  [_events addObject:event];
}

- (void)beginAction:(NSDictionary *)event { [self recordEvent:event]; }
- (void)endAction:(NSDictionary *)event { [self recordEvent:event]; }
- (void)beginBuildTarget:(NSDictionary *)event { [self recordEvent:event]; }
- (void)endBuildTarget:(NSDictionary *)event { [self recordEvent:event]; }
- (void)beginBuildCommand:(NSDictionary *)event { [self recordEvent:event]; }
- (void)endBuildCommand:(NSDictionary *)event { [self recordEvent:event]; }
- (void)beginXcodebuild:(NSDictionary *)event { [self recordEvent:event]; }
- (void)endXcodebuild:(NSDictionary *)event { [self recordEvent:event]; }
- (void)beginOcunit:(NSDictionary *)event { [self recordEvent:event]; }
- (void)endOcunit:(NSDictionary *)event { [self recordEvent:event]; }
- (void)beginTestSuite:(NSDictionary *)event { [self recordEvent:event]; }
- (void)endTestSuite:(NSDictionary *)event { [self recordEvent:event]; }
- (void)beginTest:(NSDictionary *)event { [self recordEvent:event]; }
- (void)endTest:(NSDictionary *)event { [self recordEvent:event]; }
- (void)testOutput:(NSDictionary *)event { [self recordEvent:event]; }
- (void)beginStatus:(NSDictionary *)event { [self recordEvent:event]; }
- (void)endStatus:(NSDictionary *)event { [self recordEvent:event]; }


@end
