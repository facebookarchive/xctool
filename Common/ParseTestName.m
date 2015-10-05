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

#import <Foundation/Foundation.h>

void ParseClassAndMethodFromTestName(NSString **className, NSString **methodName, NSString *testName)
{
  NSCAssert(className, @"className should be non-nil");
  NSCAssert(methodName, @"methodName should be non-nil");
  NSCAssert(testName, @"testName should be non-nil");

  static dispatch_once_t onceToken;
  static NSRegularExpression *testNameRegex;
  dispatch_once(&onceToken, ^{
    testNameRegex = [[NSRegularExpression alloc] initWithPattern:@"^-\\[([\\w.]+) ([\\w\\:]+)\\]$"
                                                         options:0
                                                           error:nil];
  });

  NSTextCheckingResult *match =
  [testNameRegex firstMatchInString:testName
                            options:0
                              range:NSMakeRange(0, [testName length])];
  NSCAssert(match && [match numberOfRanges] == 3,
            @"Test name seems to be malformed: %@", testName);

  *className = [testName substringWithRange:[match rangeAtIndex:1]];
  *methodName = [testName substringWithRange:[match rangeAtIndex:2]];
}
