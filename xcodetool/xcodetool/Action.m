
#import "Action.h"
#import "Options.h"
#import <objc/runtime.h>
#import <objc/message.h>

@class ImplicitAction;

@implementation Action

+ (NSDictionary *)options
{
  return @{};
}

+ (NSDictionary *)actionOptionWithName:(NSString *)name
                               aliases:(NSArray *)aliases
                           description:(NSString *)description
                               setFlag:(SEL)setFlagSEL
{
  NSMutableDictionary *action =
    [NSMutableDictionary dictionaryWithDictionary:@{
                                kActionOptionName: name,
                     kActionOptionSetFlagSelector: [NSString stringWithUTF8String:sel_getName(setFlagSEL)],
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
                     kActionOptionMapToSelector: [NSString stringWithUTF8String:sel_getName(mapToSEL)],
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
                     kActionOptionMapToSelector: [NSString stringWithUTF8String:sel_getName(mapToSEL)],
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

    [buffer appendString:[optionExample stringByPaddingToLength:25 withString:@" " startingAtIndex:0]];
    [buffer appendString:option[kActionOptionDescription]];
    [buffer appendString:@"\n"];
  }
  
  return buffer;
}

- (NSUInteger)consumeArguments:(NSMutableArray *)arguments errorMessage:(NSString **)errorMessage
{
  NSArray *options = [[self class] options];
  
  NSDictionary *(^namedOptionMatchingArgument)(NSString *) = ^(NSString *argument){
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
        objc_msgSend(self, sel, nextArgument);
        count += 2;
        [arguments removeObjectsInRange:NSMakeRange(0, 2)];
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

- (BOOL)validateOptions:(NSString **)errorMessage
          xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
         implicitAction:(ImplicitAction *)implicitAction
{
  // Override in subclass
  return YES;
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  return YES;
}

@end

