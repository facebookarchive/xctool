
#import "LaunchHandlers.h"

#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "TestUtil.h"

BOOL IsOtestTask(NSTask *task)
{
  if ([[[task launchPath] lastPathComponent] isEqualToString:@"otest"]) {
    return YES;
  } else if ([[[task launchPath] lastPathComponent] isEqualToString:@"sim"]) {
    // For iOS, launched via the 'sim' wrapper.
    for (NSString *arg in [task arguments]) {
      if ([[arg lastPathComponent] isEqualToString:@"otest"]) {
        return YES;
      }
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

    BOOL isOtestQuery = NO;

    if ([[task launchPath] hasSuffix:@"usr/bin/sim"]) {
      // iOS tests get queried through the 'sim' launcher.
      for (NSString *arg in [task arguments]) {
        if ([arg hasSuffix:@"otest-query-ios"]) {
          isOtestQuery = YES;
          break;
        }
      }
    } else if ([[[task launchPath] lastPathComponent] hasPrefix:@"otest-query-"]) {
      isOtestQuery = YES;
    }

    if (isOtestQuery) {
      [task pretendExitStatusOf:0];
      [task pretendTaskReturnsStandardOutput:
       [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:testList options:0 error:nil]
                              encoding:NSUTF8StringEncoding]];
      [[FakeTaskManager sharedManager] hideTaskFromLaunchedTasks:task];
    }
  } copy];
}

@end
