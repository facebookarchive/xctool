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

#import "Action.h"

#import <objc/message.h>
#import <objc/runtime.h>

#import "ReportStatus.h"

@class Options;

@implementation Action

+ (NSDictionary *)options
{
  return @{};
}

+ (NSString *)name
{
  [NSException raise:NSGenericException format:@"Subclass should have implemented 'name'."];
  return nil;
}

+ (NSDictionary *)actionOptionWithName:(NSString *)name
                               aliases:(NSArray *)aliases
                           description:(NSString *)description
                               setFlag:(SEL)setFlagSEL
{
  NSMutableDictionary *action =
    [NSMutableDictionary dictionaryWithDictionary:@{
                                kActionOptionName: name,
                     kActionOptionSetFlagSelector: @(sel_getName(setFlagSEL)),
     }];

  if (aliases) {
    action[kActionOptionAliases] = aliases;
  }

  if (description) {
    action[kActionOptionDescription] = description;
  }

  return action;
}

+ (NSDictionary *)actionOptionWithName:(NSString *)name
                               aliases:(NSArray *)aliases
                           description:(NSString *)description
                             paramName:(NSString *)paramName
                                 mapTo:(SEL)mapToSEL
{
  NSMutableDictionary *action =
  [NSMutableDictionary dictionaryWithDictionary:@{
                              kActionOptionName: name,
                     kActionOptionMapToSelector: @(sel_getName(mapToSEL)),
   }];

  if (aliases) {
    action[kActionOptionAliases] = aliases;
  }

  if (description) {
    action[kActionOptionDescription] = description;
  }
  if (paramName) {
    action[kActionOptionParamName] = paramName;
  }

  return action;
}

+ (NSDictionary *)actionOptionWithMatcher:(BOOL (^)(NSString *))matcherBlock
                              description:(NSString *)description
                                paramName:(NSString *)paramName
                                    mapTo:(SEL)mapToSEL
{
  NSMutableDictionary *action =
  [NSMutableDictionary dictionaryWithDictionary:@{
                      kActionOptionMatcherBlock: matcherBlock,
                     kActionOptionMapToSelector: @(sel_getName(mapToSEL)),
   }];

  if (description) {
    action[kActionOptionDescription] = description;
  }
  if (paramName) {
    action[kActionOptionParamName] = paramName;
  }

  return action;
}

+ (NSString *)actionUsage
{
  NSMutableString *buffer = [NSMutableString string];

  for (NSDictionary *option in [self options]) {
    if (option[kActionOptionDescription] == nil) {
      continue;
    }

    [buffer appendString:@"    "];

    NSMutableString *optionExample = [NSMutableString string];

    if (option[kActionOptionName]) {
      [optionExample appendFormat:@"-%@", option[kActionOptionName]];

      if (option[kActionOptionParamName]) {
        [optionExample appendString:@" "];
        [optionExample appendString:option[kActionOptionParamName]];
      }
    } else {
      [optionExample appendString:option[kActionOptionParamName]];
    }

    [buffer appendString:[optionExample stringByPaddingToLength:27 withString:@" " startingAtIndex:0]];
    [buffer appendString:option[kActionOptionDescription]];
    [buffer appendString:@"\n"];
  }

  return buffer;
}

- (NSUInteger)consumeArguments:(NSMutableArray *)arguments errorMessage:(NSString **)errorMessage
{
  NSArray *options = [[self class] options];

  NSDictionary *(^namedOptionMatchingArgument)(NSString *) = ^(NSString *argument){
    if ([argument hasPrefix:@"--"]) {
      argument = [argument substringFromIndex:2];
    }
    if ([argument hasPrefix:@"-"]) {
      argument = [argument substringFromIndex:1];
    }

    for (NSDictionary *option in options) {
      if ([option[kActionOptionName] isEqualToString:argument]) {
        return option;
      }

      NSArray *aliases = option[kActionOptionAliases];
      if (aliases != nil &&
          [aliases isNotEqualTo:[NSNull null]] &&
          [aliases containsObject:argument]) {
        return option;
      }
    }

    return (NSDictionary *)nil;
  };

  NSDictionary *(^matcherOptionMatchingArgument)(NSString *) = ^(NSString *argument){
    if ([argument hasPrefix:@"-"]) {
      argument = [argument substringFromIndex:1];
    }

    for (NSDictionary *option in options) {
      BOOL (^matcherBlock)(NSString *) = option[kActionOptionMatcherBlock];
      if (matcherBlock && matcherBlock(argument)) {
        return option;
      }
    }

    return (NSDictionary *)nil;
  };

  int count = 0;
  while (arguments.count > 0) {
    NSString *argument = arguments[0];
    NSDictionary *matchingNamedOption = namedOptionMatchingArgument(argument);

    // Does it match a named option?
    if (matchingNamedOption) {
      if (matchingNamedOption[kActionOptionSetFlagSelector]) {
        SEL sel = sel_registerName([matchingNamedOption[kActionOptionSetFlagSelector] UTF8String]);
        objc_msgSend(self, sel, YES);
        count++;
        [arguments removeObjectAtIndex:0];
        continue;
      } else if (matchingNamedOption[kActionOptionMapToSelector]) {
        SEL sel = sel_registerName([matchingNamedOption[kActionOptionMapToSelector] UTF8String]);
        NSString *nextArgument = arguments.count > 1 ? arguments[1] : nil;
        if(nextArgument) {
          count += 2;
          [arguments removeObjectsInRange:NSMakeRange(0, 2)];
        } else {
          *errorMessage = [NSString stringWithFormat:@"The -%@ option requires a parameter.", matchingNamedOption[kActionOptionName]];
          [arguments removeAllObjects];
          return 0;
        }
        objc_msgSend(self, sel, nextArgument);
        continue;
      }
    }

    // How about a matcher block?
    NSDictionary *matchingMatcherOption = matcherOptionMatchingArgument(argument);
    if (matchingMatcherOption) {
      SEL sel = sel_registerName([matchingMatcherOption[kActionOptionMapToSelector] UTF8String]);
      objc_msgSend(self, sel, argument);
      count++;
      [arguments removeObjectsInRange:NSMakeRange(0, 1)];
      continue;
    }

    // No match.
    break;
  }

  return count;
}

- (BOOL)validateWithOptions:(Options *)options
           xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
               errorMessage:(NSString **)errorMessage
{
  // Override in subclass
  return YES;
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  return YES;
}

@end
