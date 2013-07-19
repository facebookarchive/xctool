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

#import "BufferedReporter.h"

#import "XCToolUtil.h"

@implementation BufferedReporter

+ (NSArray *)wrapReporters:(NSArray *)reporters
{
  NSMutableArray *bufferedReporters = [NSMutableArray arrayWithCapacity:reporters.count];
  for (id<EventSink> reporter in reporters) {
    [bufferedReporters addObject:[BufferedReporter bufferedReporterWithReporter:reporter]];
  }
  return bufferedReporters;
}

+ (instancetype)bufferedReporterWithReporter:(id<EventSink>)reporter
{
  BufferedReporter *obj = [[[BufferedReporter alloc] init] autorelease];
  obj->_underlyingReporter = [reporter retain];
  obj->_bufferedEvents = [[NSMutableArray array] retain];
  return obj;
}

- (void)dealloc
{
  [_underlyingReporter release];
  [_bufferedEvents release];
  [super dealloc];
}

- (void)publishDataForEvent:(NSData *)data
{
  [_bufferedEvents addObject:data];
}

- (void)flush
{
  @synchronized(_underlyingReporter) {
    for (NSData *data in _bufferedEvents) {
      [_underlyingReporter publishDataForEvent:data];
    }
  }
  [_bufferedEvents removeAllObjects];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
  return _underlyingReporter;
}

@end
