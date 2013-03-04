
#import "CleanAction.h"
#import "Functions.h"
#import "Options.h"
#import "ActionUtil.h"
#import "BuildTestInfo.h"

@implementation CleanAction

- (BOOL)performActionWithOptions:(Options *)options buildTestInfo:(BuildTestInfo *)buildTestInfo
{
  if (![ActionUtil runXcodeBuildCommand:@"clean" withOptions:options]) {
    return NO;
  }
  
  [buildTestInfo collectInfoIfNeededWithOptions:options.implicitAction];
  
  if (![ActionUtil buildTestables:buildTestInfo.testables command:@"clean" options:options buildTestInfo:buildTestInfo]) {
    return NO;
  }
  
  return YES;
}

@end
