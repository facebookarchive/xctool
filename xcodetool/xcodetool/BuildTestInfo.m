
#import "BuildTestInfo.h"
#import "Options.h"
#import "Functions.h"
#import "ImplicitAction.h"

@implementation BuildTestInfo

- (void)collectInfoIfNeededWithOptions:(ImplicitAction *)options
{
  if (_didCollect) {
    return;
  }
  
  // First we need to know the OBJROOT and SYMROOT settings for the project we're testing.
  NSTask *task = TaskInstance();
  [task setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"]];
  [task setArguments:[[options xcodeBuildArgumentsForSubject] arrayByAddingObject:@"-showBuildSettings"]];
  [task setEnvironment:@{
   @"DYLD_INSERT_LIBRARIES" : [PathToFBXcodeTestBinaries() stringByAppendingPathComponent:@"xcodebuild-fastsettings-lib.dylib"],
   @"SHOW_ONLY_BUILD_SETTINGS_FOR_FIRST_BUILDABLE" : @"YES"
   }];
  
  NSDictionary *result = LaunchTaskAndCaptureOutput(task);
  NSDictionary *settings = BuildSettingsFromOutput(result[@"stdout"]);
  
  assert(settings.count == 1);
  NSDictionary *firstBuildable = [settings allValues][0];
  // The following control where our build output goes - we need to make sure we build the tests
  // in the same places as we built the original products - this is what Xcode does.
  self.objRoot = firstBuildable[@"OBJROOT"];
  self.symRoot = firstBuildable[@"SYMROOT"];
  self.sdkName = firstBuildable[@"SDK_NAME"];
  self.configuration = firstBuildable[@"CONFIGURATION"];
  
  if (options.workspace) {
    self.testables = TestablesInWorkspaceAndScheme(options.workspace, options.scheme);
    self.buildablesForTest = BuildablesForTestInWorkspaceAndScheme(options.workspace, options.scheme);
  } else {
    self.testables = TestablesInProjectAndScheme(options.project, options.scheme);
    self.buildablesForTest = BuildablesForTestInProjectAndScheme(options.project, options.scheme);
  }
  
  _didCollect = YES;
}

- (NSDictionary *)testableWithTarget:(NSString *)target
{
  for (NSDictionary *testable in self.testables) {
    NSString *testableTarget = testable[@"target"];
    if ([testableTarget isEqualToString:target]) {
      return testable;
    }
  }
  return nil;
}

@end
