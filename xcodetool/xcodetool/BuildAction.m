
#import "BuildAction.h"
#import "XcodeToolUtil.h"
#import "TaskUtil.h"
#import "Options.h"

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
  [task setEnvironment:@{
   @"DYLD_INSERT_LIBRARIES" : [PathToFBXcodetoolBinaries() stringByAppendingPathComponent:@"xcodebuild-lib.dylib"],
   @"PATH": @"/usr/bin:/bin:/usr/sbin:/sbin",
   }];

  [options.reporters makeObjectsPerformSelector:@selector(handleEvent:)
                                     withObject:StringForJSON(@{
                                                              @"event": @"begin-xcodebuild",
                                                              @"command": command,
                                                              @"title": options.scheme,
                                                              })];

  LaunchTaskAndFeedOuputLinesToBlock(task, ^(NSString *line){
    [options.reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:line];
  });

  [options.reporters makeObjectsPerformSelector:@selector(handleEvent:)
                                     withObject:StringForJSON(@{
                                                              @"event": @"end-xcodebuild",
                                                              @"command": command,
                                                              @"title": options.scheme,
                                                              })];

  return [task terminationStatus] == 0 ? YES : NO;
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  return [BuildAction runXcodeBuildCommand:@"build" withOptions:options];
}

@end
