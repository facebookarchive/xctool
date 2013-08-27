
#import "LaunchHandlers.h"

#import "FakeTask.h"
#import "FakeTaskManager.h"

static BOOL ArrayContainsSubArray(NSArray *arr, NSArray *subArr)
{
  NSUInteger arrCount = [arr count];
  NSUInteger subArrCount = [subArr count];

  for (int i = 0; (i < arrCount) && (i + subArrCount < arrCount); i++) {
    BOOL matches = YES;
    for (int j = 0; j < [subArr count]; j++) {
      if (![arr[i + j] isEqualTo:subArr[j]]) {
        matches = NO;
        break;
      }
    }

    if (matches) {
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
        ArrayContainsSubArray([task arguments], @[
                              @"-project",
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
        ArrayContainsSubArray([task arguments], @[
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
        ArrayContainsSubArray([task arguments], @[
                              @"-workspace",
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

@end
