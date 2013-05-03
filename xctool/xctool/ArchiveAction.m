#import "ArchiveAction.h"

#import "BuildAction.h"

@implementation ArchiveAction

+ (NSString *)name
{
  return @"archive";
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  return [BuildAction runXcodeBuildCommand:@"archive" withOptions:options];
}

@end
