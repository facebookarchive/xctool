
#import <SenTestingKit/SenTestingKit.h>

#import "EventBuffer.h"
#import "ReportStatus.h"
#import "Swizzler.h"

@interface ReportStatusTests : SenTestCase
@end

@implementation ReportStatusTests

- (void)testReportStatusMessageGeneratesTwoEventsWithTheSameTimestamp
{
  EventBuffer *buffer = [[[EventBuffer alloc] init] autorelease];

  NSDate *staticDate = [NSDate dateWithTimeIntervalSince1970:0];

  [Swizzler whileSwizzlingSelector:@selector(date)
                          forClass:[NSDate class]
                         withBlock:^{ return staticDate; }
                          runBlock:
   ^{
     ReportStatusMessage(@[buffer], REPORTER_MESSAGE_INFO, @"An info message.");
   }];

  assertThat([buffer events],
             equalTo(@[
                     @{
                     @"event" : @"begin-status",
                     @"level" : @"Info",
                     @"message" : @"An info message.",
                     @"timestamp" : @(0),
                     },
                     @{
                     @"event" : @"end-status",
                     @"level" : @"Info",
                     @"message" : @"An info message.",
                     @"timestamp" : @(0),
                     },
                     ]));
}

- (void)testReportStatusMessageBeginGeneratesAnEvent
{
  EventBuffer *buffer = [[[EventBuffer alloc] init] autorelease];

  NSDate *staticDate = [NSDate dateWithTimeIntervalSince1970:10];

  [Swizzler whileSwizzlingSelector:@selector(date)
                          forClass:[NSDate class]
                         withBlock:^{ return staticDate; }
                          runBlock:
   ^{
     ReportStatusMessageBegin(@[buffer], REPORTER_MESSAGE_INFO, @"An info message.");
   }];

  assertThat([buffer events],
             equalTo(@[
                     @{
                     @"event" : @"begin-status",
                     @"level" : @"Info",
                     @"message" : @"An info message.",
                     @"timestamp" : @(10),
                     },
                     ]));
}

- (void)testReportStatusMessageEndGeneratesAnEvent
{
  EventBuffer *buffer = [[[EventBuffer alloc] init] autorelease];

  NSDate *staticDate = [NSDate dateWithTimeIntervalSince1970:20];

  [Swizzler whileSwizzlingSelector:@selector(date)
                          forClass:[NSDate class]
                         withBlock:^{ return staticDate; }
                          runBlock:
   ^{
     ReportStatusMessageEnd(@[buffer], REPORTER_MESSAGE_INFO, @"An info message.");
   }];

  assertThat([buffer events],
             equalTo(@[
                     @{
                     @"event" : @"end-status",
                     @"level" : @"Info",
                     @"message" : @"An info message.",
                     @"timestamp" : @(20),
                     },
                     ]));
}

@end