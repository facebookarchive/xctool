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

#import "Reporter.h"

#import <poll.h>
#import <sys/stat.h>
#import <objc/runtime.h>

static void ReadFileDescriptorAndOutputLinesToBlock(int inputFD,
                                                    void (^block)(NSString *line))
{
  NSMutableString *buffer = [[NSMutableString alloc] initWithCapacity:0];

  // Split whatever content we have in 'buffer' into lines.
  void (^processBuffer)(void) = ^{
    NSUInteger offset = 0;

    for (;;) {
      NSRange newlineRange = [buffer rangeOfString:@"\n"
                                           options:0
                                             range:NSMakeRange(offset, [buffer length] - offset)];
      if (newlineRange.length == 0) {
        break;
      } else {
        NSString *line = [buffer substringWithRange:NSMakeRange(offset, newlineRange.location - offset)];
        block(line);
        offset = newlineRange.location + 1;
      }
    }

    [buffer replaceCharactersInRange:NSMakeRange(0, offset) withString:@""];
  };

  const int readBufferSize = 32768;
  uint8_t *readBuffer = malloc(readBufferSize);
  NSCAssert(readBuffer, @"Failed to alloc readBuffer");

  for (;;) {
    ssize_t bytesRead = read(inputFD, readBuffer, readBufferSize);
    NSCAssert(bytesRead != -1, @"read() failed with error: %s", strerror(errno));

    if (bytesRead > 0) {
      @autoreleasepool {
        NSString *str = [[NSString alloc] initWithBytes:readBuffer length:bytesRead encoding:NSUTF8StringEncoding];
        [buffer appendString:str];
        [str release];

        processBuffer();
      }
    } else {
      // EOF
      break;
    }
  }

  free(readBuffer);
  [buffer release];
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
      NSAssert(dict != nil, @"Failed to decode JSON '%@' with error: %@", line, [error localizedFailureReason]);
      [reporter handleEvent:dict];
    }
  });

  [reporter didFinishReporting];

  [reporter release];
}

- (void)willBeginReporting
{
  // Subclass should implement.
}

- (void)didFinishReporting
{
  // Subclass should implement.
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
  [self performSelector:sel withObject:eventDict];
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
