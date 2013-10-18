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

#import "ContainsArray.h"

#import <OCHamcrest/HCDescription.h>

@implementation ContainsArray

- (instancetype)initWithArray:(NSArray *)array
{
  if (self = [super init]) {
    _array = [array retain];
  }
  return self;
}

- (void)dealloc
{
  [_array release];
  [super dealloc];
}

- (BOOL)matches:(NSArray *)otherArray
{
  if (![otherArray isKindOfClass:[NSArray class]]) {
    return NO;
  }

  for (NSUInteger i = 0; (i < [otherArray count]) && ((i + [_array count]) <= [otherArray count]); i++) {
    BOOL matches = YES;

    for (NSUInteger j = 0; j < [_array count]; j++) {
      if (![otherArray[i + j] isEqualTo:_array[j]]) {
        matches = NO;
        break;
      }
    }

    if (matches) {
      return YES;
    }
  }

  return NO;
}

// Describe the matcher.
- (void)describeTo:(id <HCDescription>)description
{
  [[description appendText:@"array contains array: "] appendText:[_array description]];
}

@end


id <HCMatcher> containsArray(NSArray *array)
{
  return [[[ContainsArray alloc] initWithArray:array] autorelease];
}