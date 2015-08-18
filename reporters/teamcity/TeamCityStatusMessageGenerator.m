// Copyright 2004-present Facebook. All Rights Reserved.

#import "TeamCityStatusMessageGenerator.h"

@implementation TeamCityStatusMessageGenerator

+ (NSString *)escapeCharacter:(NSString *)inputString
{
  NSMutableString *escapedString = [inputString mutableCopy];
  [escapedString replaceOccurrencesOfString:@"|" withString:@"||" options:0 range:NSMakeRange(0, [escapedString length])];
  [escapedString replaceOccurrencesOfString:@"'" withString:@"|'" options:0 range:NSMakeRange(0, [escapedString length])];
  [escapedString replaceOccurrencesOfString:@"\n" withString:@"|n" options:0 range:NSMakeRange(0, [escapedString length])];
  [escapedString replaceOccurrencesOfString:@"\r" withString:@"|r" options:0 range:NSMakeRange(0, [escapedString length])];
  [escapedString replaceOccurrencesOfString:@"[" withString:@"|[" options:0 range:NSMakeRange(0, [escapedString length])];
  [escapedString replaceOccurrencesOfString:@"]" withString:@"|]" options:0 range:NSMakeRange(0, [escapedString length])];
  return escapedString;
}

@end
