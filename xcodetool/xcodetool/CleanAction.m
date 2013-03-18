
#import "CleanAction.h"
#import "Functions.h"
#import "Options.h"
#import "ActionUtil.h"
#import "XcodeSubjectInfo.h"

@implementation CleanAction

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  if (![ActionUtil runXcodeBuildCommand:@"clean" withOptions:options]) {
    return NO;
  }
  
  if (![ActionUtil buildTestables:xcodeSubjectInfo.testables command:@"clean" options:options xcodeSubjectInfo:xcodeSubjectInfo]) {
    return NO;
  }
  
  return YES;
}

@end
