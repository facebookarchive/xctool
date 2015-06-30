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

#import "ArchiveAction.h"

#import "BuildAction.h"
#import "Options.h"
#import "XCToolUtil.h"
#import "XcodeSubjectInfo.h"

@interface ArchiveAction ()

@property (nonatomic, copy) NSString *archivePath;

@end

@implementation ArchiveAction

+ (NSString *)name
{
  return @"archive";
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  NSMutableArray *arguments = [[options xcodeBuildArgumentsForSubject] mutableCopy];
  [arguments addObjectsFromArray:[options commonXcodeBuildArgumentsForSchemeAction:@"ArchiveAction"
                                                                  xcodeSubjectInfo:xcodeSubjectInfo]];
  [arguments addObject:@"archive"];

  if (_archivePath)
  {
    [arguments addObjectsFromArray:@[@"-archivePath", _archivePath]];
  }

  [xcodeSubjectInfo.actionScripts preArchiveWithOptions:options];

  BOOL ret = RunXcodebuildAndFeedEventsToReporters(arguments,
                                                   @"archive",
                                                   [options scheme],
                                                   [options reporters]);

  [xcodeSubjectInfo.actionScripts postArchiveWithOptions:options];

  return ret;
}

+ (NSArray *)options
{
  return
  @[
    [Action actionOptionWithName:@"archivePath"
                         aliases:nil
                     description:@"PATH where created archive will be placed."
                       paramName:@"PATH"
                           mapTo:@selector(setArchivePath:)],
    ];
}


@end
