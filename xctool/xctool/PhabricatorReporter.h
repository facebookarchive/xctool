// Copyright 2004-present Facebook. All Rights Reserved.


#import "Reporter.h"

/**
 PhabricatorReporter produces a JSON array which you can plug directly into the
 'arc:unit' diff property in Phabricator.
 */
@interface PhabricatorReporter : Reporter
{
  NSMutableArray *_results;
  NSMutableArray *_currentTargetFailures;
  NSDictionary *_currentBuildCommand;
  NSString *_projectOrWorkspaceName;
}

- (NSString *)arcUnitJSON;

@end
