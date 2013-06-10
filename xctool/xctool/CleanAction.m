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

#import "CleanAction.h"

#import "BuildAction.h"
#import "BuildTestsAction.h"
#import "Options.h"
#import "XcodeSubjectInfo.h"
#import "XCToolUtil.h"

@implementation CleanAction

+ (NSString *)name
{
  return @"clean";
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  // First, clean the build products from 'build'.  These are the same build
  // products generated by Build or Build & Run in Xcode.
  NSArray *arguments = [[[options xcodeBuildArgumentsForSubject]
                         arrayByAddingObjectsFromArray:[options commonXcodeBuildArgumentsForSchemeAction:@"LaunchAction"
                                                                                        xcodeSubjectInfo:xcodeSubjectInfo]]
                        arrayByAddingObject:@"clean"];
  if (!RunXcodebuildAndFeedEventsToReporters(arguments,
                                             @"clean",
                                             [options scheme],
                                             [options reporters])) {
    return NO;
  }

  // Then, clean the build products created by 'build-tests' or 'test'.  These
  // are the same build products generated by the Test action in Xcode.
  NSArray *buildables = [xcodeSubjectInfo testablesAndBuildablesForTest];
  if (![BuildTestsAction buildTestables:buildables
                                command:@"clean"
                                options:options
                       xcodeSubjectInfo:xcodeSubjectInfo]) {
    return NO;
  }

  return YES;
}

@end
