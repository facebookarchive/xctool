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

#import "EventBuffer.h"

#import "XCToolUtil.h"

@interface EventBuffer ()
@property (nonatomic, strong) id<EventSink> underlyingSink;
@property (nonatomic, copy) NSMutableArray *bufferedEventData;
@end

@implementation EventBuffer

+ (NSArray *)wrapSinks:(NSArray *)sinks
{
  NSMutableArray *buffers = [NSMutableArray arrayWithCapacity:sinks.count];
  for (id<EventSink> sink in sinks) {
    [buffers addObject:[EventBuffer eventBufferForSink:sink]];
  }
  return buffers;
}

+ (instancetype)eventBufferForSink:(id<EventSink>)reporter
{
  EventBuffer *obj = [[EventBuffer alloc] init];
  obj.underlyingSink = reporter;
  return obj;
}

- (instancetype)init
{
  if (self = [super init]) {
    _bufferedEventData = [[NSMutableArray alloc] init];
  }
  return self;
}


- (void)publishDataForEvent:(NSData *)data
{
  [_bufferedEventData addObject:data];
}

- (void)flush
{
  @synchronized(_underlyingSink) {
    for (NSData *data in _bufferedEventData) {
      [_underlyingSink publishDataForEvent:data];
    }
  }
  [_bufferedEventData removeAllObjects];
}

- (NSArray *)events
{
  NSMutableArray *result = [NSMutableArray array];

  for (NSData *data in _bufferedEventData) {
    NSError *error = nil;
    NSDictionary *event = [NSJSONSerialization JSONObjectWithData:data
                                                          options:0
                                                            error:&error];
    NSAssert(event != nil, @"Error encoding JSON: %@", [error localizedFailureReason]);
    [result addObject:event];
  }

  return result;
}

@end
