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

#import "EventGenerator.h"
#import "FakeFileHandle.h"
#import "Reporter+Testing.h"
#import "ReporterEvents.h"
#import "TextReporter.h"

@interface TextReporterTests : XCTestCase
@end

@implementation TextReporterTests

/**
 Just verify the plumbing works and our text reporters don't crash when getting
 fed events.  This is a really lame test - over time, we should add cases to
 actually verify output.
 */
- (void)testReporterDoesntCrash
{
  void (^pumpReporter)(Class, NSString *) = ^(Class cls, NSString *path) {
    NSLog(@"pumpReporter(%@, %@) ...", cls, path);

    // Pump the events to make sure all the plumbing works and we don't crash.
    [cls outputDataWithEventsFromFile:path];
  };

  pumpReporter([PlainTextReporter class], TEST_DATA @"JSONStreamReporter-build-good.txt");
  pumpReporter([PlainTextReporter class], TEST_DATA @"JSONStreamReporter-build-bad.txt");
  pumpReporter([PlainTextReporter class], TEST_DATA @"JSONStreamReporter-runtests.txt");

  pumpReporter([PrettyTextReporter class], TEST_DATA @"JSONStreamReporter-build-good.txt");
  pumpReporter([PrettyTextReporter class], TEST_DATA @"JSONStreamReporter-build-bad.txt");
  pumpReporter([PrettyTextReporter class], TEST_DATA @"JSONStreamReporter-runtests.txt");
}

- (void)testStatusMessageShowsOneLineWithNoDuration
{
    NSArray *events = @[
      EventDictionaryWithNameAndContent(kReporter_Events_BeginStatus, @{
        kReporter_BeginStatus_MessageKey: @"Some message...",
        kReporter_TimestampKey: @1,
        kReporter_BeginStatus_LevelKey: @"Info",
        }),
      EventDictionaryWithNameAndContent(kReporter_Events_EndStatus, @{
        kReporter_EndStatus_MessageKey: @"Some message...",
        kReporter_TimestampKey: @1,
        kReporter_EndStatus_LevelKey: @"Info",
        }),
      ];

  assertThat([PrettyTextReporter outputStringWithEvents:events],
             equalTo(// the first line, from beginStatusMessage:
                     @"\r[Info] Some message..."
                     // the second line, from endStatusMessage:
                     @"\r[Info] Some message...\n"
                     // the trailing newline from -[Reporter close]
                     @"\n"));
}

- (void)testStatusMessageWithBeginAndEndIncludesDuration
{
    NSArray *events = @[
      // begin at T+0 seconds.
      EventDictionaryWithNameAndContent(kReporter_Events_BeginStatus, @{
        kReporter_BeginStatus_MessageKey: @"Some message...",
        kReporter_TimestampKey: @1,
        kReporter_BeginStatus_LevelKey: @"Info",
        }),
      // begin at T+1 seconds.
      EventDictionaryWithNameAndContent(kReporter_Events_EndStatus, @{
        kReporter_EndStatus_MessageKey: @"Some message.",
        kReporter_TimestampKey: @2,
        kReporter_EndStatus_LevelKey: @"Info",
        }),
      ];

  assertThat([PrettyTextReporter outputStringWithEvents:events],
             equalTo(// the first line, from beginStatusMessage:
                     @"\r[Info] Some message..."
                     // the second line, from endStatusMessage:
                     @"\r[Info] Some message. (1000 ms)\n"
                     // the trailing newline from -[Reporter close]
                     @"\n"));
}

- (void) testContextString
{
  NSString *testDataPath = TEST_DATA @"ContextTest.m";
  NSString *context = [TextReporter getContext:testDataPath errorLine:13 colNumber:38];
  NSString *refString = @"10 @implementation ContextTest\n11 \n12 static int test() {\n13   NSObject *blah = [[NSObject alloc] init];\n     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^~~~~~\n14 }\n15 ";
  assertThat(context, equalTo(refString));
}

- (void) testContextStringUnderlineWithTrailingWhitespace
{
  NSString *testDataPath = TEST_DATA @"ContextTest.m";
  NSString *context = [TextReporter getContext:testDataPath errorLine:17 colNumber:38];
  NSRange range = [context rangeOfCharacterFromSet:([NSCharacterSet characterSetWithCharactersInString:@"~^"])];
  range.length = [context rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"~^"] options:NSBackwardsSearch].location - range.location + 1;
  NSString *substr = [context substringWithRange:range];
  NSString *refSubstr = @"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^~~~~~";
  assertThat(substr, equalTo(refSubstr));
}

- (void) testContextStringErrorLoadingFileReturnsNil
{
  NSString *testDataPath = nil;
  NSString *context = [TextReporter getContext:testDataPath errorLine:14 colNumber:39];
  assertThat(context, equalTo(nil));
}

@end
