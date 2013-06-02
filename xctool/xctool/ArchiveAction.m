#import "ArchiveAction.h"

#import "BuildAction.h"
#import "Options.h"
#import "XCToolUtil.h"

@implementation ArchiveAction

+ (NSString *)name
{
  return @"archive";
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  NSArray *arguments = [[[options xcodeBuildArgumentsForSubject]
                        arrayByAddingObjectsFromArray:[options commonXcodeBuildArgumentsForSchemeAction:@"ArchiveAction"
                                                                                       xcodeSubjectInfo:xcodeSubjectInfo]]
                        arrayByAddingObject:@"archive"];
  return RunXcodebuildAndFeedEventsToReporters(arguments,
                                               @"archive",
                                               [options scheme],
                                               [options reporters]);
}

@end
