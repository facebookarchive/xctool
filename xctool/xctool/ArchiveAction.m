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
  return RunXcodebuildAndFeedEventsToReporters([[options xcodeBuildArgumentsForSubject] arrayByAddingObject:@"archive"],
                                               @"archive",
                                               [options scheme],
                                               [options reporters]);
}

@end
