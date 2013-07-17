
#import <SenTestingKit/SenTestingKit.h>

#import "RecordingReporter.h"
#import "Reporter.h"
#import "ReportStatus.h"
#import "Swizzler.h"

@interface ReporterTests : SenTestCase
@end

@implementation ReporterTests

- (void)testReportStatusMessageGeneratesTwoEventsWithTheSameTimestamp
{
  RecordingReporter *reporter = [[[RecordingReporter alloc] init] autorelease];

  NSDate *staticDate = [NSDate dateWithTimeIntervalSince1970:0];

  [Swizzler whileSwizzlingSelector:@selector(date)
                          forClass:[NSDate class]
                         withBlock:^{ return staticDate; }
                          runBlock:
   ^{
     ReportStatusMessage(@[reporter], REPORTER_MESSAGE_INFO, @"An info message.");
   }];

  assertThat([reporter events],
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
  RecordingReporter *reporter = [[[RecordingReporter alloc] init] autorelease];

  NSDate *staticDate = [NSDate dateWithTimeIntervalSince1970:10];

  [Swizzler whileSwizzlingSelector:@selector(date)
                          forClass:[NSDate class]
                         withBlock:^{ return staticDate; }
                          runBlock:
   ^{
     ReportStatusMessageBegin(@[reporter], REPORTER_MESSAGE_INFO, @"An info message.");
   }];

  assertThat([reporter events],
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
  RecordingReporter *reporter = [[[RecordingReporter alloc] init] autorelease];

  NSDate *staticDate = [NSDate dateWithTimeIntervalSince1970:20];

  [Swizzler whileSwizzlingSelector:@selector(date)
                          forClass:[NSDate class]
                         withBlock:^{ return staticDate; }
                          runBlock:
   ^{
     ReportStatusMessageEnd(@[reporter], REPORTER_MESSAGE_INFO, @"An info message.");
   }];

  assertThat([reporter events],
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