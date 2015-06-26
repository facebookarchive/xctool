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

#import <SenTestingKit/SenTestingKit.h>

#import "FakeFileHandle.h"
#import "Options.h"
#import "Options+Testing.h"
#import "Reporter+Testing.h"
#import "ReportStatus.h"
#import "Swizzler.h"
#import "TextReporter.h"

@interface TextReporterTests : SenTestCase
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
    Options *options = [[[Options alloc] init] autorelease];
    options.workspace = TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj";
    options.scheme = @"TestProject-Library";

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
  FakeFileHandle *fh = [[[FakeFileHandle alloc] init] autorelease];
  PrettyTextReporter *reporter = [[[PrettyTextReporter alloc] init] autorelease];
  // Force _isPretty to YES to avoid the isatty() detection.
  reporter->_isPretty = YES;

  [reporter setOutputPath:@"-"];
  [reporter openWithStandardOutput:(NSFileHandle *)fh error:nil];

  ReportStatusMessage(@[reporter], REPORTER_MESSAGE_INFO, @"Some message...");

  [reporter close];
  assertThat([fh stringWritten],
             equalTo(// the first line, from beginStatusMessage:
                     @"\r[Info] Some message..."
                     // the second line, from endStatusMessage:
                     @"\r[Info] Some message...\n"
                     // the trailing newline from -[Reporter close]
                     @"\n"));
}

- (void)testStatusMessageWithBeginAndEndIncludesDuration
{
  FakeFileHandle *fh = [[[FakeFileHandle alloc] init] autorelease];
  PrettyTextReporter *reporter = [[[PrettyTextReporter alloc] init] autorelease];
  // Force _isPretty to YES to avoid the isatty() detection.
  reporter->_isPretty = YES;

  [reporter setOutputPath:@"-"];
  [reporter openWithStandardOutput:(NSFileHandle *)fh error:nil];

  // call begin at T+0 seconds.
  [Swizzler whileSwizzlingSelector:@selector(date)
                          forClass:[NSDate class]
                         withBlock:^{ [NSDate dateWithTimeIntervalSince1970:0]; }
                          runBlock:
   ^{
     ReportStatusMessageBegin(@[reporter], REPORTER_MESSAGE_INFO, @"Some message...");
   }];

  // call end at T+1 seconds.
  [Swizzler whileSwizzlingSelector:@selector(date)
                          forClass:[NSDate class]
                         withBlock:^{ [NSDate dateWithTimeIntervalSince1970:1.0]; }
                          runBlock:
   ^{
     ReportStatusMessageEnd(@[reporter], REPORTER_MESSAGE_INFO, @"Some message.");
   }];

  [reporter close];
  assertThat([fh stringWritten],
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
