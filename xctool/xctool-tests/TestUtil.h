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

#import <Foundation/Foundation.h>

#import "Action.h"
#import "XCTool.h"

@interface TestUtil : NSObject

+ (Options *)optionsFromArgumentList:(NSArray *)argumentList;

+ (Options *)validatedReporterOptionsFromArgumentList:(NSArray *)argumentList;

+ (void)assertThatReporterOptionsValidateWithArgumentList:(NSArray *)argumentList;
+ (void)assertThatReporterOptionsValidateWithArgumentList:(NSArray *)argumentList failsWithMessage:(NSString *)message;

+ (Options *)validatedOptionsFromArgumentList:(NSArray *)argumentList;

+ (void)assertThatOptionsValidateWithArgumentList:(NSArray *)argumentList;
+ (void)assertThatOptionsValidateWithArgumentList:(NSArray *)argumentList failsWithMessage:(NSString *)message;

+ (NSDictionary *)runWithFakeStreams:(XCTool *)tool;

@end
