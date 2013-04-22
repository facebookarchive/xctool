#import "XcodeTargetMatch.h"

@implementation XcodeTargetMatch

- (NSString *)description {
  return [NSString stringWithFormat:@"%@ workspace: %@ project: %@ scheme: %@ num targets: %lu",
    [super description], _workspacePath, _projectPath, _schemeName, _numTargetsInScheme];
}

- (void)dealloc {
  [_workspacePath release];
  [_projectPath release];
  [_schemeName release];
  [super dealloc];
}

@end
