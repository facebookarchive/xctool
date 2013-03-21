
#import "CleanAction.h"
#import "Functions.h"
#import "ActionUtil.h"
#import "XcodeSubjectInfo.h"

@implementation CleanAction

- (BOOL)performActionWithOptions:(ImplicitAction *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
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
