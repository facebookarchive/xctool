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

#define kActionOptionName @"kActionOptionName"
#define kActionOptionMatcherBlock @"kActionOptionMatcherBlock"
#define kActionOptionParamName @"kActionOptionParamName"
#define kActionOptionAliases @"kActionOptionAliases"
#define kActionOptionDescription @"kActionOptionDescription"
#define kActionOptionMapToSelector @"kActionOptionMapToSelector"
#define kActionOptionSetFlagSelector @"kActionOptionSetFlagSelector"

@class Options;
@class XcodeSubjectInfo;

@interface Action : NSObject

+ (NSArray *)options;
+ (NSString *)name;

+ (NSDictionary *)actionOptionWithName:(NSString *)name
                               aliases:(NSArray *)aliases
                           description:(NSString *)description
                             paramName:(NSString *)paramName
                                 mapTo:(SEL)mapToSEL;

+ (NSDictionary *)actionOptionWithName:(NSString *)name
                               aliases:(NSArray *)aliases
                           description:(NSString *)description
                               setFlag:(SEL)setFlagSEL;

+ (NSDictionary *)actionOptionWithMatcher:(BOOL (^)(NSString *))matcherBlock
                              description:(NSString *)description
                                paramName:(NSString *)paramName
                                    mapTo:(SEL)mapToSEL;

+ (NSString *)actionUsage;

- (NSUInteger)consumeArguments:(NSMutableArray *)arguments errorMessage:(NSString **)errorMessage;

/**
 Perform any pre-flight validation that the action needs.  An action might
 check that required arguments are present, or that they have the right values.

 @param Options The main Options object with xctool-wide options.
 @param XcodeSubjectInfo The XcodeSubjectInfo option, which gathers a bunch of
   information about the subject workspace/project being built or tested.
 @param string Out parameter that error message will be written to.
 @return YES if the action passed validation.
 */
- (BOOL)validateWithOptions:(Options *)options
           xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
               errorMessage:(NSString **)errorMessage;

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo;

@end
