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

#import "ContainsAssertionFailure.h"

@implementation ContainsAssertionFailure

+ (instancetype)containsAssertionFailureFromMethod:(NSString *)method
{
  return [[self alloc] initWithMethod:method];
}

- (instancetype)initWithMethod:(NSString *)method
{
  if (self = [super init]) {
    _method = method;
  }
  return self;
}


- (BOOL)matches:(id)item
{
  // We only care about strings
  if (![item isKindOfClass:[NSString class]]) {
    return NO;
  }

  NSString *string = (NSString *)item;

  // Build up the regex pattern
  NSString *prefix = @"*** Assertion failure in ";
  NSString *escapedMethod = [NSRegularExpression escapedPatternForString:_method];
  NSString *escapedPrefix = [NSRegularExpression escapedPatternForString:prefix];
  NSString *pattern = [escapedPrefix stringByAppendingFormat:@"(__\\d+)?%@", escapedMethod];

  // Execute the regex
  NSError *error = nil;
  NSRegularExpression *regex;
  regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                    options:0
                                                      error:&error];
  NSAssert(!error,
           @"Fatal: error creating regex pattern.\n"
           @"item: %@\n"
           @"_method: %@\n"
           @"XCTool crashed. Please report this bug with the above information.",
           item, _method);

  NSRange rangeOfFirstMatch = [regex rangeOfFirstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
  return !(NSEqualRanges(rangeOfFirstMatch, NSMakeRange(NSNotFound, 0)));
}

// Describe the matcher.
- (void)describeTo:(id <HCDescription>)description
{
  [[[description appendText:@"assertion failure in method '"] appendText:_method] appendText:@"' not found."];
}

@end

id <HCMatcher> containsAssertionFailureFromMethod(NSString *method)
{
  return [ContainsAssertionFailure containsAssertionFailureFromMethod:method];
}
