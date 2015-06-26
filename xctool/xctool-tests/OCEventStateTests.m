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
#import "EventSink.h"
#import "OCEventState.h"
#import "ReporterEvents.h"
#import "TestUtil.h"

@interface OCEventStateTests : XCTestCase
@end

@implementation OCEventStateTests

- (void)testParseEvent
{
  OCEventState *state = [[OCEventState alloc] initWithReporters: @[]];
  XCTAssertEqualObjects([state reporters], @[], @"Reporters are not equal");
}

- (void)testPublishWithEvent
{
  EventBuffer *eventBuffer = [[EventBuffer alloc] init];
  OCEventState *state = [[OCEventState alloc] initWithReporters:@[eventBuffer]];

  NSDictionary *event = @{@"ilove": @"jello"};
  [state publishWithEvent:event];

  assertThatInteger([eventBuffer.events count], equalToInteger(1));
  assertThat(eventBuffer.events[0], equalTo(event));
}

@end
