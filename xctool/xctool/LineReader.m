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

#import "LineReader.h"

@interface LineReader ()
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, copy) NSMutableString *buffer;
@end

@implementation LineReader

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle
{
  if (self = [super init]) {
    _fileHandle = fileHandle;
    _buffer = [[NSMutableString alloc] initWithCapacity:0];
  }
  return self;
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
      _didReadLineBlock(line);
      offset = newlineRange.location + 1;
    }
  }

  [_buffer replaceCharactersInRange:NSMakeRange(0, offset) withString:@""];
}

- (void)appendDataToBuffer:(NSData *)data
{
  NSString *dataToAppend = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  if (dataToAppend) {
    [_buffer appendString:dataToAppend];
  }
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
