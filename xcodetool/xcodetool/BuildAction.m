
#import "BuildAction.h"
#import "Functions.h"
#import "Options.h"
#import "ActionUtil.h"

@implementation BuildAction

- (BOOL)performActionWithOptions:(Options *)options buildTestInfo:(BuildTestInfo *)buildTestInfo
{
  return [ActionUtil runXcodeBuildCommand:@"build" withOptions:options];
}

@end
