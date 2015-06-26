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

#import "ContainsArray.h"

#import <OCHamcrest/HCDescription.h>

#import "TestUtil.h"

@implementation ContainsArray

- (instancetype)initWithArray:(NSArray *)array
{
  if (self = [super init]) {
    _array = array;
  }
  return self;
}


- (BOOL)matches:(NSArray *)otherArray
{
  if (![otherArray isKindOfClass:[NSArray class]]) {
    return NO;
  }

  return ArrayContainsSubsequence(otherArray, _array);
}

// Describe the matcher.
- (void)describeTo:(id <HCDescription>)description
{
  [[description appendText:@"array contains array: "] appendText:[_array description]];
}

@end


id <HCMatcher> containsArray(NSArray *array)
{
  return [[ContainsArray alloc] initWithArray:array];
}
