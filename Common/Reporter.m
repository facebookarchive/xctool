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

#import "ReporterEvents.h"
#import "TaskUtil.h"

@implementation Reporter

+ (void)readFromInput:(NSFileHandle *)inputHandle
          andOutputTo:(NSFileHandle *)outputHandle
{
  Reporter *reporter = [[[self class] alloc] init];
  reporter->_outputHandle = outputHandle;

  [reporter willBeginReporting];

  int fildes[1] = {inputHandle.fileDescriptor};
  ReadOutputsAndFeedOuputLinesToBlockOnQueue(fildes, 1, ^(int fd, NSString *line){
    if (line.length == 0) {
      return;
    }

    @autoreleasepool {
      NSError *error = nil;
      NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:&error];
      NSCAssert(dict != nil, @"Failed to decode JSON '%@' with error: %@", line, [error localizedFailureReason]);
      [reporter handleEvent:dict];
    }
  }, NULL, NULL, YES);

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

  NSString *event = eventDict[kReporter_Event_Key];
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
- (void)simulatorOutput:(NSDictionary *)event {}
- (void)beginStatus:(NSDictionary *)event {}
- (void)endStatus:(NSDictionary *)event {}
- (void)analyzerResult:(NSDictionary *)event {}

@end
