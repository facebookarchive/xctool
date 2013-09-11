//
// Copyright 2013 Facebook
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

#import "TestUtil.h"

#import "FakeTask.h"
#import "Options.h"
#import "XCTool.h"
#import "XcodeSubjectInfo.h"
#import "FakeFileHandle.h"
#import "ReporterTask.h"
#import "XCToolUtil.h"

@implementation TestUtil

+ (NSDictionary *)runWithFakeStreams:(XCTool *)tool
{
  __block NSString *standardOutput = nil;
  __block NSString *standardError = nil;

  NSPipe *standardOutputPipe = [NSPipe pipe];
  NSFileHandle *standardOutputReadHandle = [standardOutputPipe fileHandleForReading];
  NSFileHandle *standardOutputWriteHandle = [standardOutputPipe fileHandleForWriting];

  NSPipe *standardErrorPipe = [NSPipe pipe];
  NSFileHandle *standardErrorReadHandle = [standardErrorPipe fileHandleForReading];
  NSFileHandle *standardErrorWriteHandle = [standardErrorPipe fileHandleForWriting];

  void (^completionBlock)(NSNotification *) = ^(NSNotification *notification){
    NSData *data = notification.userInfo[NSFileHandleNotificationDataItem];
    NSString *str = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

    if (notification.object == standardOutputReadHandle) {
      standardOutput = str;
    } else if (notification.object == standardErrorReadHandle) {
      standardError = str;
    }

    CFRunLoopStop(CFRunLoopGetCurrent());
  };

  id standardOutputObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleReadToEndOfFileCompletionNotification
                                                                                object:standardOutputReadHandle
                                                                                 queue:nil
                                                                            usingBlock:completionBlock];
  [standardOutputReadHandle readToEndOfFileInBackgroundAndNotify];
  id standardErrorObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleReadToEndOfFileCompletionNotification
                                                                               object:standardErrorReadHandle
                                                                                queue:nil
                                                                           usingBlock:completionBlock];
  [standardErrorReadHandle readToEndOfFileInBackgroundAndNotify];

  tool.standardOutput = standardOutputWriteHandle;
  tool.standardError = standardErrorWriteHandle;

  [tool run];

  [standardOutputWriteHandle closeFile];
  [standardErrorWriteHandle closeFile];

  // Run until we've seen end-of-file for both streams.
  while (standardOutput == nil || standardError == nil) {
    CFRunLoopRun();
  }

  [[NSNotificationCenter defaultCenter] removeObserver:standardOutputObserver];
  [[NSNotificationCenter defaultCenter] removeObserver:standardErrorObserver];

  return @{@"stdout" : standardOutput, @"stderr" : standardError};
}

+ (NSArray *)getEventsForStates:(NSArray *)states
                      withBlock:(void (^)(void))block
{
  NSString *fakeStandardOutputPath = MakeTempFileWithPrefix(@"fake-stdout");
  NSString *fakeStandardErrorPath = MakeTempFileWithPrefix(@"fake-stderr");

  ReporterTask *rt = [[[ReporterTask alloc] initWithReporterPath:@"/bin/cat"
                                                      outputPath:@"-"] autorelease];
  NSString *error = nil;
  BOOL opened = [rt openWithStandardOutput:[NSFileHandle fileHandleForWritingAtPath:fakeStandardOutputPath]
                             standardError:[NSFileHandle fileHandleForWritingAtPath:fakeStandardErrorPath]
                                     error:&error];
  assertThatBool(opened, equalToBool(YES));

  [states makeObjectsPerformSelector:@selector(setReporters:) withObject:@[rt]];

  block();

  [rt close];

  NSString *fakeStandardOutput = [NSString stringWithContentsOfFile:fakeStandardOutputPath
                                                           encoding:NSUTF8StringEncoding
                                                              error:nil];

  NSMutableArray *events = [[[NSMutableArray alloc] init] autorelease];
  NSMutableArray *lines = [[fakeStandardOutput componentsSeparatedByString:@"\n"] mutableCopy];;
  [lines removeObjectAtIndex:[lines count] - 1];
  [lines enumerateObjectsUsingBlock:^(NSString *line, NSUInteger idx, BOOL *stop) {
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    [events addObject: [NSJSONSerialization JSONObjectWithData:data
                                                       options:0
                                                         error:nil]];
  }];

  return events;
}

@end
