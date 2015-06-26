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

#import "EventSink.h"

/*!
 Buffers calls to the underlying sink until this buffer is flushed.
 */
@interface EventBuffer : NSObject <EventSink>

+ (instancetype)eventBufferForSink:(id<EventSink>)sink;

/*!
 Convenience function that wraps an array of Reporters with BufferedReporters.
 */
+ (NSArray *)wrapSinks:(NSArray *)sinks;

/*!
 Atomically flush all events into the underlying reporter
 */
- (void)flush;

/*!
 All objects (as dictionaries) that have been published to the buffer.
 */
- (NSArray *)events;

@end
