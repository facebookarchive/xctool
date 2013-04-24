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

#import "JSONStreamReporter.h"

@implementation JSONStreamReporter

- (void)passThrough:(NSDictionary *)event
{
  NSError *error = nil;
  NSData *eventData = [NSJSONSerialization dataWithJSONObject:event
                                                      options:0
                                                        error:&error];
  NSAssert(eventData != nil,
           @"Failed to encode event with error: %@ for event: %@",
           [error localizedFailureReason], event);

  [self.outputHandle writeData:eventData];
  [self.outputHandle writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)beginAction:(NSDictionary *)event { [self passThrough:event]; }
- (void)endAction:(NSDictionary *)event { [self passThrough:event]; }
- (void)beginBuildTarget:(NSDictionary *)event { [self passThrough:event]; }
- (void)endBuildTarget:(NSDictionary *)event { [self passThrough:event]; }
- (void)beginBuildCommand:(NSDictionary *)event { [self passThrough:event]; }
- (void)endBuildCommand:(NSDictionary *)event { [self passThrough:event]; }
- (void)beginXcodebuild:(NSDictionary *)event { [self passThrough:event]; }
- (void)endXcodebuild:(NSDictionary *)event { [self passThrough:event]; }
- (void)beginOctest:(NSDictionary *)event { [self passThrough:event]; }
- (void)endOctest:(NSDictionary *)event { [self passThrough:event]; }
- (void)beginTestSuite:(NSDictionary *)event { [self passThrough:event]; }
- (void)endTestSuite:(NSDictionary *)event { [self passThrough:event]; }
- (void)beginTest:(NSDictionary *)event { [self passThrough:event]; }
- (void)endTest:(NSDictionary *)event { [self passThrough:event]; }
- (void)testOutput:(NSDictionary *)event { [self passThrough:event]; }
- (void)message:(NSDictionary *)event { [self passThrough:event]; }

@end
