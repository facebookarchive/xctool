
#import "BuildAction.h"

#import "Options.h"
#import "Reporter.h"
#import "TaskUtil.h"
#import "XcodeToolUtil.h"

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
