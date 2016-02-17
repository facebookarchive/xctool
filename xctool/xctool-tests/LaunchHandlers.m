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

#import "LaunchHandlers.h"

#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "TestUtil.h"

/**
 * Returns YES if task is spawning xctest process via simctl.
 */
BOOL IsSimctlSpawnXctestTask(NSTask *task)
{
  if (![[task launchPath] hasSuffix:@"usr/bin/simctl"]) {
    return NO;
  }

  if (![[task arguments] containsObject:@"spawn"]) {
    return NO;
  }

  for (NSString *arg in [task arguments]) {
    if ([arg hasSuffix:@"usr/bin/xctest"]) {
      return YES;
    }
  }

  return NO;
}

@implementation LaunchHandlers

+ (id)handlerForShowBuildSettingsWithProject:(NSString *)project
                                      scheme:(NSString *)scheme
                                settingsPath:(NSString *)settingsPath
{
  return [self handlerForShowBuildSettingsWithAction:nil
                                             project:project
                                              scheme:scheme
                                        settingsPath:settingsPath
                                                hide:YES];
}

+ (id)handlerForShowBuildSettingsWithProject:(NSString *)project
                                      scheme:(NSString *)scheme
                                settingsPath:(NSString *)settingsPath
                                        hide:(BOOL)hide
{
  return [self handlerForShowBuildSettingsWithAction:nil
                                             project:project
                                              scheme:scheme
                                        settingsPath:settingsPath
                                                hide:hide];
}

+ (id)handlerForShowBuildSettingsWithAction:(NSString *)action
                                    project:(NSString *)project
                                     scheme:(NSString *)scheme
                               settingsPath:(NSString *)settingsPath
                                       hide:(BOOL)hide
{
  return [^(FakeTask *task){
    BOOL match = YES;
    match = [[task launchPath] hasSuffix:@"xcodebuild"];
    match &= ArrayContainsSubsequence([task arguments], @[@"-project",
                                                          project,
                                                          @"-scheme",
                                                          scheme,
                                                          ]);
    match &= ![task environment][@"SHOW_ONLY_BUILD_SETTINGS_FOR_TARGET"];
    if (action) {
      match &= ArrayContainsSubsequence([task arguments], @[action, @"-showBuildSettings"]);
    } else {
      match &= [[task arguments] containsObject:@"-showBuildSettings"];
    }

    if (match) {
      [task pretendTaskReturnsStandardOutput:
       [NSString stringWithContentsOfFile:settingsPath
                                 encoding:NSUTF8StringEncoding
                                    error:nil]];
      if (hide) {
        // The tests don't care about this - just exclude from 'launchedTasks'
        [[FakeTaskManager sharedManager] hideTaskFromLaunchedTasks:task];
      }
    }
  } copy];
}

+ (id)handlerForShowBuildSettingsWithProject:(NSString *)project
                                      target:(NSString *)target
                                settingsPath:(NSString *)settingsPath
                                        hide:(BOOL)hide
{
  return [^(FakeTask *task){
    if ([[task launchPath] hasSuffix:@"xcodebuild"] &&
        ArrayContainsSubsequence([task arguments], @[
                                                     @"-project",
                                                     project,
                                                     @"-target",
                                                     target,
                                                     ]) &&
        [[task environment][@"SHOW_ONLY_BUILD_SETTINGS_FOR_TARGET"] isEqual:target] &&
        [[task arguments] containsObject:@"-showBuildSettings"])
    {
      [task pretendTaskReturnsStandardOutput:
       [NSString stringWithContentsOfFile:settingsPath
                                 encoding:NSUTF8StringEncoding
                                    error:nil]];
      if (hide) {
        // The tests don't care about this - just exclude from 'launchedTasks'
        [[FakeTaskManager sharedManager] hideTaskFromLaunchedTasks:task];
      }
    }
  } copy];
}

+ (id)handlerForShowBuildSettingsErrorWithProject:(NSString *)project
                                           target:(NSString *)target
                                 errorMessagePath:(NSString *)errorMessagePath
                                             hide:(BOOL)hide
{
  return [^(FakeTask *task){
    if ([[task launchPath] hasSuffix:@"xcodebuild"] &&
        ArrayContainsSubsequence([task arguments], @[@"-project",
                                                     project,
                                                     @"-target",
                                                     target,
                                                     ]) &&
        [[task arguments] containsObject:@"-showBuildSettings"])
    {
      [task pretendTaskReturnsStandardError:
       [NSString stringWithContentsOfFile:errorMessagePath
                                 encoding:NSUTF8StringEncoding
                                    error:nil]];
      if (hide) {
        // The tests don't care about this - just exclude from 'launchedTasks'
        [[FakeTaskManager sharedManager] hideTaskFromLaunchedTasks:task];
      }
    }
  } copy];
}

+ (id)handlerForShowBuildSettingsWithWorkspace:(NSString *)workspace
                                        scheme:(NSString *)scheme
                                  settingsPath:(NSString *)settingsPath
{
  return [self handlerForShowBuildSettingsWithWorkspace:workspace
                                                 scheme:scheme
                                           settingsPath:settingsPath
                                                   hide:YES];
}

+ (id)handlerForShowBuildSettingsWithWorkspace:(NSString *)workspace
                                        scheme:(NSString *)scheme
                                  settingsPath:(NSString *)settingsPath
                                          hide:(BOOL)hide
{
  return [^(FakeTask *task){
    if ([[task launchPath] hasSuffix:@"xcodebuild"] &&
        ArrayContainsSubsequence([task arguments], @[@"-workspace",
                                                     workspace,
                                                     @"-scheme",
                                                     scheme,
                                                     ]) &&
        [[task arguments] containsObject:@"-showBuildSettings"])
    {
      [task pretendTaskReturnsStandardOutput:
       [NSString stringWithContentsOfFile:settingsPath
                                 encoding:NSUTF8StringEncoding
                                    error:nil]];
      if (hide) {
        // The tests don't care about this - just exclude from 'launchedTasks'
        [[FakeTaskManager sharedManager] hideTaskFromLaunchedTasks:task];
      }
    }
  } copy];
}

+ (id)handlerForOtestQueryReturningTestList:(NSArray *)testList
{
  return [^(FakeTask *task){

    NSString *otestQueryOutputFilePath = nil;

    if ([[task launchPath] hasSuffix:@"usr/bin/simctl"]) {
      // iOS tests get queried through the 'simctl' launcher.
      for (NSString *arg in [task arguments]) {
        if ([arg hasSuffix:@"otest-query-ios"]) {
          otestQueryOutputFilePath = task.environment[@"SIMCTL_CHILD_OTEST_QUERY_OUTPUT_FILE"];
          break;
        }
      }
    } else if ([[[task launchPath] lastPathComponent] hasPrefix:@"otest-query-"]) {
      otestQueryOutputFilePath = task.environment[@"OTEST_QUERY_OUTPUT_FILE"];
    }

    if (otestQueryOutputFilePath) {
      [task pretendExitStatusOf:0];
      [[NSJSONSerialization dataWithJSONObject:testList options:0 error:nil] writeToFile:otestQueryOutputFilePath atomically:YES];
      [[FakeTaskManager sharedManager] hideTaskFromLaunchedTasks:task];
    }
  } copy];
}

+ (id)handlerForOtestQueryWithTestHost:(NSString *)testHost
                     returningTestList:(NSArray *)testList
{
  return [^(FakeTask *task){

    NSString *otestQueryOutputFilePath = nil;

    if ([[task launchPath] hasSuffix:@"usr/bin/simctl"]) {
      // iOS tests get queried through the 'simctl' launcher.
      if ([task environment][@"SIMCTL_CHILD_OtestQueryBundlePath"]) {
        for (NSString *arg in [task arguments]) {
          if ([arg hasSuffix:testHost]) {
            otestQueryOutputFilePath = task.environment[@"SIMCTL_CHILD_OTEST_QUERY_OUTPUT_FILE"];
            break;
          }
        }
      }
    } else if ([[task launchPath] isEqualToString:testHost]) {
      otestQueryOutputFilePath = task.environment[@"OTEST_QUERY_OUTPUT_FILE"];
    }

    if (otestQueryOutputFilePath) {
      [task pretendExitStatusOf:0];
      [[NSJSONSerialization dataWithJSONObject:testList options:0 error:nil] writeToFile:otestQueryOutputFilePath atomically:YES];
      [[FakeTaskManager sharedManager] hideTaskFromLaunchedTasks:task];
    }
  } copy];
}

+ (id)handlerForSimctlXctestRunReturningTestEvents:(NSData *)testEvents
{
  return [^(FakeTask *task){

    if (!IsSimctlSpawnXctestTask(task)) {
      return;
    }

    NSString *outputFilePath = task.environment[@"SIMCTL_CHILD_OTEST_SHIM_STDOUT_FILE"];
    if (!outputFilePath) {
      return;
    }

    [task pretendExitStatusOf:0];
    [testEvents writeToFile:outputFilePath atomically:YES];
  } copy];
}

@end
