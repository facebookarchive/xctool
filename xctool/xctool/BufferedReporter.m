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

@implementation BufferedReporter

+ (instancetype)bufferedReporterWithReporter:(Reporter *)reporter
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

- (void)handleEvent:(NSDictionary *)event
{
  [_bufferedEvents addObject:event];
}

- (void)flush
{
  @synchronized(_underlyingReporter) {
    for (NSDictionary *event in _bufferedEvents) {
      [_underlyingReporter handleEvent:event];
    }
  }
  [_bufferedEvents removeAllObjects];
}

- (void)close
{
  [self flush];
  [_underlyingReporter close];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
  return _underlyingReporter;
}

@end
