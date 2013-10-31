
#import "LaunchHandlers.h"

#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "TestUtil.h"

@implementation LaunchHandlers

+ (id)handlerForShowBuildSettingsWithProject:(NSString *)project
                                      scheme:(NSString *)scheme
                                settingsPath:(NSString *)settingsPath
{
  return [self handlerForShowBuildSettingsWithProject:project
                                               scheme:scheme
                                         settingsPath:settingsPath
                                                 hide:YES];
}

+ (id)handlerForShowBuildSettingsWithProject:(NSString *)project
                                      scheme:(NSString *)scheme
                                settingsPath:(NSString *)settingsPath
                                        hide:(BOOL)hide
{
  return [[^(FakeTask *task){
    if ([[task launchPath] hasSuffix:@"xcodebuild"] &&
        ArrayContainsSubsequence([task arguments], @[@"-project",
                                                     project,
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
  } copy] autorelease];
}

+ (id)handlerForShowBuildSettingsWithProject:(NSString *)project
                                      target:(NSString *)target
                                settingsPath:(NSString *)settingsPath
                                        hide:(BOOL)hide
{
  return [[^(FakeTask *task){
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
  } copy] autorelease];
}

+ (id)handlerForShowBuildSettingsErrorWithProject:(NSString *)project
                                           target:(NSString *)target
                                 errorMessagePath:(NSString *)errorMessagePath
                                             hide:(BOOL)hide
{
  return [[^(FakeTask *task){
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
  } copy] autorelease];
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
  return [[^(FakeTask *task){
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
  } copy] autorelease];
}

+ (id)handlerForOtestQueryReturningTestList:(NSArray *)testList
{
  return [[^(FakeTask *task){

    BOOL isOtestQuery = NO;

    if ([[task launchPath] hasSuffix:@"otest-query-osx"] ||
        [[task launchPath] hasSuffix:@"otest-query-ios"]) {
      isOtestQuery = YES;
    }

    if (isOtestQuery) {
      [task pretendExitStatusOf:0];
      [task pretendTaskReturnsStandardOutput:
       [[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:testList options:0 error:nil]
                              encoding:NSUTF8StringEncoding] autorelease]];
      [[FakeTaskManager sharedManager] hideTaskFromLaunchedTasks:task];
    }
  } copy] autorelease];
}

+ (id)handlerForXcodeBuildVersionWithVersion:(NSString *)versionString
                                        hide:(BOOL)hide
{
  return [[^(FakeTask *task){
    if ([[task launchPath] hasSuffix:@"xcodebuild"] &&
        [[task arguments] containsObject:@"-version"])
    {
      [task pretendTaskReturnsStandardOutput:[NSString stringWithFormat:@"Xcode %@\nBuild version xctool-tests\n", versionString]];
      if (hide) {
        // The tests don't care about this - just exclude from 'launchedTasks'
        [[FakeTaskManager sharedManager] hideTaskFromLaunchedTasks:task];
      }
    }
  } copy] autorelease];
}

@end
