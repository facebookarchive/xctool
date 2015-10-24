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

#import "BuildAction.h"

#import "Options.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"
#import "XcodeSubjectInfo.h"

@implementation BuildAction


+ (NSString *)name
{
  return @"build";
}

+ (NSArray *)options
{
  return
  @[
    [Action actionOptionWithName:@"dry-run"
                         aliases:@[@"n"]
                     description:@"print the commands that would be executed, but do not execute them"
                         setFlag:@selector(setOnlyPrintCommandNames:)],
    [Action actionOptionWithName:@"skipUnavailableActions"
                         aliases:nil
                     description:@"skip build actions that cannot be performed instead of failing. This option is only honored if -scheme is passed"
                         setFlag:@selector(setSkipUnavailableActions:)],
    ];
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{

  [xcodeSubjectInfo.actionScripts preBuildWithOptions:options];

  NSArray *arguments = [self xcodebuildArgumentsForActionWithOptions:options xcodeSubjectInfo:xcodeSubjectInfo];

  BOOL ret = RunXcodebuildAndFeedEventsToReporters(arguments,
                                                   @"build",
                                                   [options scheme],
                                                   [options reporters]);

  [xcodeSubjectInfo.actionScripts postBuildWithOptions:options];

  return ret;
}

- (NSArray *)xcodebuildArgumentsForActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  NSMutableArray *arguments = [NSMutableArray array];

  [arguments addObjectsFromArray:[options xcodeBuildArgumentsForSubject]];
  [arguments addObjectsFromArray:[options commonXcodeBuildArgumentsForSchemeAction:@"LaunchAction"
                                                                  xcodeSubjectInfo:xcodeSubjectInfo]];

  if (_onlyPrintCommandNames) {
    [arguments addObject:@"-dry-run"];
  }
  if (_skipUnavailableActions) {
    [arguments addObject:@"-skipUnavailableActions"];
  }

  [arguments addObject:@"build"];

  return [NSArray arrayWithArray:arguments];
}

@end
