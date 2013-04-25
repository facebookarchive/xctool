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

#import "BuildAction.h"

#import "Options.h"
#import "Reporter.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"

@implementation BuildAction

+ (NSString *)name
{
  return @"build";
}

+ (BOOL)runXcodeBuildCommand:(NSString *)command withOptions:(Options *)options
{
  NSTask *task = TaskInstance();
  [task setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"]];
  [task setArguments:[[options xcodeBuildArgumentsForSubject] arrayByAddingObject:command]];
  NSMutableDictionary *environment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
  [environment addEntriesFromDictionary:@{
   @"DYLD_INSERT_LIBRARIES" : [PathToXCToolBinaries() stringByAppendingPathComponent:@"xcodebuild-shim.dylib"],
   @"PATH": @"/usr/bin:/bin:/usr/sbin:/sbin",
  }];
  [task setEnvironment:environment];

  [options.reporters makeObjectsPerformSelector:@selector(handleEvent:)
                                     withObject:@{
   @"event": kReporter_Events_BeginXcodebuild,
   @"command": command,
   @"title": options.scheme,
   }];

  LaunchTaskAndFeedOuputLinesToBlock(task, ^(NSString *line){
    NSError *error = nil;
    NSDictionary *event = [NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding]
                                                          options:0
                                                            error:&error];
    NSCAssert(error == nil, @"Got error while trying to deserialize event '%@': %@", line, [error localizedFailureReason]);

    [options.reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:event];
  });

  [options.reporters makeObjectsPerformSelector:@selector(handleEvent:)
                                     withObject:@{
   @"event": @"end-xcodebuild",
   @"command": command,
   @"title": options.scheme,
   }];

  return [task terminationStatus] == 0 ? YES : NO;
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  return [BuildAction runXcodeBuildCommand:@"build" withOptions:options];
}

@end
