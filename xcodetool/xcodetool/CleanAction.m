
#import "CleanAction.h"
#import "XcodeToolUtil.h"
#import "XcodeSubjectInfo.h"
#import "BuildAction.h"
#import "BuildTestsAction.h"

@implementation CleanAction

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  if (![BuildAction runXcodeBuildCommand:@"clean" withOptions:options]) {
    return NO;
  }
  
  if (![BuildTestsAction buildTestables:xcodeSubjectInfo.testables command:@"clean" options:options xcodeSubjectInfo:xcodeSubjectInfo]) {
    return NO;
  }
  
  return YES;
}

@end
