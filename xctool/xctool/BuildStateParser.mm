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

#import "BuildStateParser.h"

#include <fstream>
#include <memory>

@implementation BuildStateParser

- (instancetype)initWithPath:(NSString *)path;
{
  if (self = [super init]) {
    [self loadFromPath:path];
  }
  return self;
}

- (void)loadFromPath:(NSString *)path
{
  std::ifstream input(path.UTF8String);

  std::unique_ptr<char[]> buf(new char[1024*1024*10]);

  NSMutableArray *nodePaths = [NSMutableArray array];

  while (!input.eof()) {
    input.getline(buf.get(), 1024*1024*10);

    switch (buf[0]) {
      case 'T': // XCBuildableState
        //    r -
        //    c -
        //    t - time
        //    v -
        break;
      case 'C': // XCBuildCommandState
        //    e - end time
        //    l - serialized IDEActivityLogSection
        //    o - output line
        //    r - return code
        //    s - start time
        //    x -
        break;
      case 'N': // XCBuildNodeState
      {
        //    b - "buildCommandInputSignature"
        //    c - "contentSignature"
        //    t - time

        // the rest of string is a file name, that's all we require for now
        NSString *filename = @(&buf[1]);
        if (filename.length) {
          [nodePaths addObject:filename];
        }
        break;
      }
      case '#':
        // comment
        break;
      case '\0':
        // blank
        break;
      default:
        break;
    }
  }

  _nodes = nodePaths;
}


@end
