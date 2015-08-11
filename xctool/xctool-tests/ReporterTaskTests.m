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

#import "FakeFileHandle.h"
#import "ReporterTask.h"
#import "XCToolUtil.h"

@interface ReporterTaskTests : XCTestCase
@end

@implementation ReporterTaskTests

- (void)testReporterTaskCanOutputToStandardOutput
{
  NSString *fakeStandardOutputPath = MakeTempFileWithPrefix(@"fake-stdout");

  ReporterTask *rt = [[ReporterTask alloc] initWithReporterPath:@"/bin/cat"
                                                      outputPath:@"-"];
  NSString *error = nil;
  BOOL opened = [rt openWithStandardOutput:[NSFileHandle fileHandleForWritingAtPath:fakeStandardOutputPath]
                             standardError:[NSFileHandle fileHandleWithStandardError]
                                     error:&error];
  assertThatBool(opened, isTrue());

  PublishEventToReporters(@[rt], @{@"event":@"some-fake-event"});

  [rt close];

  NSString *fakeStandardOutput = [NSString stringWithContentsOfFile:fakeStandardOutputPath
                                                           encoding:NSUTF8StringEncoding
                                                              error:nil];
  assertThat(fakeStandardOutput, equalTo(@"{\"event\":\"some-fake-event\"}\n"));
}

- (void)testReporterTaskCanOutputToAnOutputFile
{
  NSString *fakeStandardOutputPath = MakeTempFileWithPrefix(@"fake-stdout");
  NSString *someOutputPath = MakeTempFileWithPrefix(@"some-output");

  ReporterTask *rt = [[ReporterTask alloc] initWithReporterPath:@"/bin/cat"
                                                      outputPath:someOutputPath];
  NSString *error = nil;
  BOOL opened = [rt openWithStandardOutput:[NSFileHandle fileHandleForWritingAtPath:fakeStandardOutputPath]
                             standardError:[NSFileHandle fileHandleWithStandardError]
                                     error:&error];
  assertThatBool(opened, isTrue());

  PublishEventToReporters(@[rt], @{@"event":@"some-fake-event"});

  [rt close];

  NSString *fakeStandardOutput = [NSString stringWithContentsOfFile:fakeStandardOutputPath
                                                           encoding:NSUTF8StringEncoding
                                                              error:nil];
  NSString *someOutput = [NSString stringWithContentsOfFile:someOutputPath
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
  assertThat(someOutput, equalTo(@"{\"event\":\"some-fake-event\"}\n"));
  // Nothing should get written to stdout
  assertThat(fakeStandardOutput, equalTo(@""));
}

@end
