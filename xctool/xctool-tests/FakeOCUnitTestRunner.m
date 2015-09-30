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

#import "FakeOCUnitTestRunner.h"

#import "TaskUtil.h"

@interface FakeOCUnitTestRunner ()
{
  int lastLineIndex;
}
@property (nonatomic, strong) NSArray *outputLines;
@end

@implementation FakeOCUnitTestRunner


- (void)setOutputLines:(NSArray *)lines
{
  _outputLines = lines;
  lastLineIndex = -1;
}

- (void)runTestsAndFeedOutputTo:(FdOutputLineFeedBlock)outputLineBlock
                   startupError:(NSString **)startupError
                    otherErrors:(NSString **)otherErrors
{
  for (lastLineIndex++; lastLineIndex < [_outputLines count]; lastLineIndex++) {
    if ([_outputLines[lastLineIndex] isEqualToString:@"__break__"]) {
      return;
    }
    outputLineBlock(0, _outputLines[lastLineIndex]);
  }
}

@end
