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

#import "LineReader.h"

@implementation LineReader

- (id)initWithFileHandle:(NSFileHandle *)fileHandle
{
  if (self = [super init]) {
    _fileHandle = [fileHandle retain];
    _buffer = [[NSMutableString alloc] initWithCapacity:0];
  }
  return self;
}

- (void)dealloc
{
  [_fileHandle release];
  [_buffer release];
  [super dealloc];
}

- (void)processBuffer
{
  NSUInteger offset = 0;

  for (;;) {
    NSRange newlineRange = [_buffer rangeOfString:@"\n"
                                          options:0
                                            range:NSMakeRange(offset, [_buffer length] - offset)];

    if (newlineRange.length == 0) {
      break;
    } else {
      NSString *line = [_buffer substringWithRange:NSMakeRange(offset, newlineRange.location - offset)];
      self.didReadLineBlock(line);
      offset = newlineRange.location + 1;
    }
  }

  [_buffer replaceCharactersInRange:NSMakeRange(0, offset) withString:@""];
}

- (void)appendDataToBuffer:(NSData *)data
{
  [_buffer appendString:[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]];
}

- (void)dataAvailableNotification:(NSNotification *)notification
{
  NSData *data = [_fileHandle availableData];

  if (data.length > 0) {
    [self appendDataToBuffer:data];
    [self processBuffer];
  }

  [_fileHandle waitForDataInBackgroundAndNotify];
}

- (void)startReading
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(dataAvailableNotification:)
                                               name:NSFileHandleDataAvailableNotification
                                             object:_fileHandle];
  [_fileHandle waitForDataInBackgroundAndNotify];
}

- (void)stopReading
{
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:NSFileHandleDataAvailableNotification
                                                object:_fileHandle];
}

- (void)finishReadingToEndOfFile
{
  [self appendDataToBuffer:[_fileHandle readDataToEndOfFile]];
  [self processBuffer];
}

@end
