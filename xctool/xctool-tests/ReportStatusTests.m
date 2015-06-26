//
// Copyright 2004-present Facebook. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <XCTest/XCTest.h>

#import "EventBuffer.h"
#import "ReportStatus.h"
#import "Swizzler.h"

@interface ReportStatusTests : XCTestCase
@end

@implementation ReportStatusTests

- (void)testReportStatusMessageGeneratesTwoEventsWithTheSameTimestamp
{
  EventBuffer *buffer = [[EventBuffer alloc] init];

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
                     @"timestamp" : @0,
                     },
                     @{
                     @"event" : @"end-status",
                     @"level" : @"Info",
                     @"message" : @"An info message.",
                     @"timestamp" : @0,
                     },
                     ]));
}

- (void)testReportStatusMessageBeginGeneratesAnEvent
{
  EventBuffer *buffer = [[EventBuffer alloc] init];

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
                     @"timestamp" : @10,
                     },
                     ]));
}

- (void)testReportStatusMessageEndGeneratesAnEvent
{
  EventBuffer *buffer = [[EventBuffer alloc] init];

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
                     @"timestamp" : @20,
                     },
                     ]));
}

@end
