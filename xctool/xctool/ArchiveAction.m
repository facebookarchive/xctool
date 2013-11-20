#import "ArchiveAction.h"

#import "BuildAction.h"
#import "Options.h"
#import "XCToolUtil.h"

@interface ArchiveAction ()

@property (nonatomic, retain) NSString *archivePath;

@end

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
  if (_archivePath)
  {
    arguments = [arguments arrayByAddingObjectsFromArray:@[@"-archivePath", _archivePath]];
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
  self.archivePath = nil;
  [super dealloc];
}

- (void)setArchivePath:(NSString *)archivePath
{
  _archivePath = archivePath;
}


@end
