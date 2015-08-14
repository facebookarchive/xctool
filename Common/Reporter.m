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

#import "Reporter.h"

#import <objc/runtime.h>
#import <poll.h>
#import <sys/stat.h>

static void ReadFileDescriptorAndOutputLinesToBlock(int inputFD,
                                                    void (^block)(NSString *line))
{
  NSMutableData *buffer = [NSMutableData dataWithCapacity:0];

  // Split whatever content we have in 'buffer' into lines.
  void (^processBuffer)(void) = ^{
    NSUInteger offset = 0;
    NSData *newlineData = [NSData dataWithBytes:"\n" length:1];
    for (;;) {
      NSRange newlineRange = [buffer rangeOfData:newlineData
                                         options:0
                                           range:NSMakeRange(offset, [buffer length] - offset)];
      if (newlineRange.length == 0) {
        break;
      } else {
        NSData *line = [buffer subdataWithRange:NSMakeRange(offset, newlineRange.location - offset)];
        block([[NSString alloc] initWithData:line encoding:NSUTF8StringEncoding]);
        offset = newlineRange.location + 1;
      }
    }

    [buffer replaceBytesInRange:NSMakeRange(0, offset) withBytes:NULL length:0];
  };

  const int readBufferSize = 32768;
  uint8_t *readBuffer = malloc(readBufferSize);
  NSCAssert(readBuffer, @"Failed to alloc readBuffer");

  for (;;) {
    ssize_t bytesRead = read(inputFD, readBuffer, readBufferSize);
    NSCAssert(bytesRead != -1, @"read() failed with error: %s", strerror(errno));

    if (bytesRead > 0) {
      @autoreleasepool {
        [buffer appendBytes:readBuffer length:bytesRead];

        processBuffer();
      }
    } else {
      // EOF
      break;
    }
  }

  free(readBuffer);
}

@implementation Reporter

+ (void)readFromInput:(NSFileHandle *)inputHandle
          andOutputTo:(NSFileHandle *)outputHandle
{
  Reporter *reporter = [[[self class] alloc] init];
  reporter->_outputHandle = outputHandle;

  [reporter willBeginReporting];

  ReadFileDescriptorAndOutputLinesToBlock([inputHandle fileDescriptor], ^(NSString *line){
    @autoreleasepool {
      NSError *error = nil;
      NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:&error];
      NSCAssert(dict != nil, @"Failed to decode JSON '%@' with error: %@", line, [error localizedFailureReason]);
      [reporter handleEvent:dict];
    }
  });

  [reporter didFinishReporting];

}

- (void)willBeginReporting
{
  // Subclass should implement.
}

- (void)didFinishReporting
{
  // Subclass should implement.
}

- (void)parseAndHandleEvent:(NSString *)line
{
  NSError *error = nil;
  NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding]
                                                       options:0
                                                         error:&error];
  if (dict != nil) {
    [self handleEvent:dict];
  }
}

- (void)handleEvent:(NSDictionary *)eventDict
{
  NSAssert(([eventDict count] > 0), @"Event was empty.");

  NSString *event = eventDict[@"event"];
  NSAssert(event != nil && [event length] > 0, @"Event name was empty for event: %@", eventDict);

  NSMutableString *selectorName = [NSMutableString string];

  int i = 0;
  for (NSString *part in [event componentsSeparatedByString:@"-"]) {
    if (i++ == 0) {
      [selectorName appendString:[part lowercaseString]];
    } else {
      [selectorName appendString:[[part lowercaseString] capitalizedString]];
    }
  }
  [selectorName appendString:@":"];

  SEL sel = sel_registerName([selectorName UTF8String]);

  if ([self respondsToSelector:sel]) {
    ((void (*)(id, SEL, NSDictionary *))[self methodForSelector:sel])(self, sel, eventDict);
  }
}

- (void)beginAction:(NSDictionary *)event {}
- (void)endAction:(NSDictionary *)event {}
- (void)beginBuildTarget:(NSDictionary *)event {}
- (void)endBuildTarget:(NSDictionary *)event {}
- (void)beginBuildCommand:(NSDictionary *)event {}
- (void)endBuildCommand:(NSDictionary *)event {}
- (void)beginXcodebuild:(NSDictionary *)event {}
- (void)endXcodebuild:(NSDictionary *)event {}
- (void)beginOcunit:(NSDictionary *)event {}
- (void)endOcunit:(NSDictionary *)event {}
- (void)beginTestSuite:(NSDictionary *)event {}
- (void)endTestSuite:(NSDictionary *)event {}
- (void)beginTest:(NSDictionary *)event {}
- (void)endTest:(NSDictionary *)event {}
- (void)testOutput:(NSDictionary *)event {}
- (void)beginStatus:(NSDictionary *)event {}
- (void)endStatus:(NSDictionary *)event {}
- (void)analyzerResult:(NSDictionary *)event {}

@end
