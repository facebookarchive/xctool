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

#import "FakeFileHandle.h"

@implementation FakeFileHandle

- (instancetype)init
{
  if (self = [super init]) {
    _dataWritten = [[NSMutableData alloc] initWithCapacity:0];
  }
  return self;
}

- (void)writeData:(NSData *)data
{
  [_dataWritten appendData:data];
}

- (NSData *)dataWritten
{
  return _dataWritten;
}

- (NSString *)stringWritten
{
  return [[NSString alloc] initWithData:_dataWritten
                                encoding:NSUTF8StringEncoding];
}

- (int)fileDescriptor {
  // Not true, but this will appease some callers.
  return STDOUT_FILENO;
}

- (void)synchronizeFile
{
}

@end
