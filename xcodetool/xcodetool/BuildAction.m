
#import "BuildAction.h"
#import "Functions.h"
#import "ActionUtil.h"

@implementation BuildAction

- (BOOL)performActionWithOptions:(ImplicitAction *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  return [ActionUtil runXcodeBuildCommand:@"build" withOptions:options];
}

@end
