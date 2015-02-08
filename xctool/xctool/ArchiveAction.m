#import "ArchiveAction.h"

#import "BuildAction.h"
#import "Options.h"
#import "XCToolUtil.h"

@interface ArchiveAction ()

@property (nonatomic, copy) NSString *archivePath;

@end

@implementation ArchiveAction

+ (NSString *)name
{
  return @"archive";
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  NSMutableArray *arguments = [[[options xcodeBuildArgumentsForSubject] mutableCopy] autorelease];
  [arguments addObjectsFromArray:[options commonXcodeBuildArgumentsForSchemeAction:@"ArchiveAction"
                                                                  xcodeSubjectInfo:xcodeSubjectInfo]];
  [arguments addObject:@"archive"];

  if (_archivePath)
  {
    [arguments addObjectsFromArray:@[@"-archivePath", _archivePath]];
  }

  return RunXcodebuildAndFeedEventsToReporters(arguments,
                                               @"archive",
                                               [options scheme],
                                               [options reporters]);
}

+ (NSArray *)options
{
  return
  @[
    [Action actionOptionWithName:@"archivePath"
                         aliases:nil
                     description:@"PATH where created archive will be placed."
                       paramName:@"PATH"
                           mapTo:@selector(setArchivePath:)],
    ];
}

- (void)dealloc {
  _archivePath = nil;
  [super dealloc];
}

@end
