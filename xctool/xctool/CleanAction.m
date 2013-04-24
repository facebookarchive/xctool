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
#import "XcodeSubjectInfo.h"
#import "XCToolUtil.h"

@implementation CleanAction

+ (NSString *)name
{
  return @"clean";
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  if (![BuildAction runXcodeBuildCommand:@"clean" withOptions:options]) {
    return NO;
  }

  if (![BuildTestsAction buildTestables:xcodeSubjectInfo.testables command:@"clean" options:options xcodeSubjectInfo:xcodeSubjectInfo]) {
    return NO;
  }

  return YES;
}

@end
