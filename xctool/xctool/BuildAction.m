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

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{

  [xcodeSubjectInfo.actionScripts preBuildWithOptions:options];


  NSArray *arguments = [[[options xcodeBuildArgumentsForSubject]
                         arrayByAddingObjectsFromArray:[options commonXcodeBuildArgumentsForSchemeAction:@"LaunchAction"
                                                                                        xcodeSubjectInfo:xcodeSubjectInfo]]
                        arrayByAddingObject:@"build"];

  BOOL ret = RunXcodebuildAndFeedEventsToReporters(arguments,
                                               @"build",
                                               [options scheme],
                                               [options reporters]);

  [xcodeSubjectInfo.actionScripts postBuildWithOptions:options];

  return ret;
}

@end
