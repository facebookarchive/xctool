
#import "ActionUtil.h"
#import "Options.h"
#import "Functions.h"
#import "ImplicitAction.h"
#import "ApplicationTestRunner.h"
#import "LogicTestRunner.h"
#import "XcodeSubjectInfo.h"

@implementation ActionUtil

+ (BOOL)runXcodeBuildCommand:(NSString *)command withOptions:(Options *)options
{
  NSTask *task = TaskInstance();
  [task setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"]];
  [task setArguments:[[options.implicitAction xcodeBuildArgumentsForSubject] arrayByAddingObject:command]];
  [task setEnvironment:@{
   @"DYLD_INSERT_LIBRARIES" : [PathToFBXcodetoolBinaries() stringByAppendingPathComponent:@"xcodebuild-lib.dylib"],
   @"PATH": @"/usr/bin:/bin:/usr/sbin:/sbin",
   }];
  
  [options.implicitAction.reporters makeObjectsPerformSelector:@selector(handleEvent:)
                                                    withObject:StringForJSON(@{
                                                                             @"event": @"begin-xcodebuild",
                                                                             @"command": command,
                                                                             @"title": options.implicitAction.scheme,
                                                                             })];
  
  LaunchTaskAndFeedOuputLinesToBlock(task, ^(NSString *line){
    [options.implicitAction.reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:line];
  });
  
  [options.implicitAction.reporters makeObjectsPerformSelector:@selector(handleEvent:)
                                                    withObject:StringForJSON(@{
                                                                             @"event": @"end-xcodebuild",
                                                                             @"command": command,
                                                                             @"title": options.implicitAction.scheme,
                                                                             })];
  
  return [task terminationStatus] == 0 ? YES : NO;
}

+ (BOOL)buildTestable:(NSDictionary *)testable
            reporters:(NSArray *)reporters
              objRoot:(NSString *)objRoot
              symRoot:(NSString *)symRoot
       xcodeArguments:(NSArray *)xcodeArguments
         xcodeCommand:(NSString *)xcodeCommand
{
  NSString *testableProjectPath = testable[@"projectPath"];
  NSString *testableTarget = testable[@"target"];
  
  NSArray *taskArguments = [xcodeArguments arrayByAddingObjectsFromArray:@[
                            @"-project", testableProjectPath,
                            @"-target", testableTarget,
                            [NSString stringWithFormat:@"OBJROOT=%@", objRoot],
                            [NSString stringWithFormat:@"SYMROOT=%@", symRoot],
                            xcodeCommand,
                            ]];
  
  // Build the test target.
  NSTask *buildTask = TaskInstance();
  [buildTask setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"]];
  [buildTask setArguments:taskArguments];
  [buildTask setEnvironment:@{
   @"DYLD_INSERT_LIBRARIES" : [PathToFBXcodetoolBinaries() stringByAppendingPathComponent:@"xcodebuild-lib.dylib"],
   @"PATH": @"/usr/bin:/bin:/usr/sbin:/sbin",
   }];
  
  [reporters makeObjectsPerformSelector:@selector(handleEvent:)
                             withObject:StringForJSON(@{
                                                      @"event": @"begin-xcodebuild",
                                                      @"command": [xcodeCommand stringByAppendingString:@"-test"],
                                                      @"title": testableTarget,
                                                      })];
  
  LaunchTaskAndFeedOuputLinesToBlock(buildTask, ^(NSString *line){
    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:line];
  });
  
  [reporters makeObjectsPerformSelector:@selector(handleEvent:)
                             withObject:StringForJSON(@{
                                                      @"event": @"end-xcodebuild",
                                                      @"command": [xcodeCommand stringByAppendingString:@"-test"],
                                                      @"title": testableTarget,
                                                      })];
  
  return ([buildTask terminationStatus] == 0);
}

+ (BOOL)buildTestables:(NSArray *)testables
               command:(NSString *)command
               options:(Options *)options
         xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  for (NSDictionary *testable in testables) {
    BOOL succeeded = [self buildTestable:testable
                               reporters:options.implicitAction.reporters
                                 objRoot:xcodeSubjectInfo.objRoot
                                 symRoot:xcodeSubjectInfo.symRoot
                          xcodeArguments:[options.implicitAction commonXcodeBuildArguments]
                            xcodeCommand:command];
    if (!succeeded) {
      return NO;
    }
  }
  return YES;
}

+ (BOOL)runTestable:(NSDictionary *)testable
          reproters:(NSArray *)reporters
            objRoot:(NSString *)objRoot
            symRoot:(NSString *)symRoot
     xcodeArguments:(NSArray *)xcodeArguments
            testSDK:(NSString *)testSDK
        senTestList:(NSString *)senTestList
 senTestInvertScope:(BOOL)senTestInvertScope
{
  NSString *testableProjectPath = testable[@"projectPath"];
  NSString *testableTarget = testable[@"target"];
  
  // Collect build settings for this test target.
  NSTask *settingsTask = TaskInstance();
  [settingsTask setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"]];
  [settingsTask setArguments:[xcodeArguments arrayByAddingObjectsFromArray:@[
                              @"-sdk", testSDK,
                              @"-project", testableProjectPath,
                              @"-target", testableTarget,
                              [NSString stringWithFormat:@"OBJROOT=%@", objRoot],
                              [NSString stringWithFormat:@"SYMROOT=%@", symRoot],
                              @"-showBuildSettings",
                              ]]];
  [settingsTask setEnvironment:@{
   @"DYLD_INSERT_LIBRARIES" : [PathToFBXcodetoolBinaries() stringByAppendingPathComponent:@"xcodebuild-fastsettings-lib.dylib"],
   @"SHOW_ONLY_BUILD_SETTINGS_FOR_TARGET" : testableTarget,
   }];
  
  NSDictionary *result = LaunchTaskAndCaptureOutput(settingsTask);
  NSDictionary *allSettings = BuildSettingsFromOutput(result[@"stdout"]);
  assert(allSettings.count == 1);
  NSDictionary *testableBuildSettings = allSettings[testableTarget];
  
  assert([testableBuildSettings[@"SDK_NAME"] hasPrefix:@"iphonesimulator"]);
  
  Class testRunnerClass = {0};
  
  if (testableBuildSettings[@"TEST_HOST"] != nil) {
    testRunnerClass = [ApplicationTestRunner class];
  } else {
    testRunnerClass = [LogicTestRunner class];
  }
  
  TestRunner *testRunner = [[[testRunnerClass alloc]
                             initWithBuildSettings:testableBuildSettings
                             senTestList:senTestList
                             senTestInvertScope:senTestInvertScope
                             standardOutput:nil
                             standardError:nil
                             reporters:reporters] autorelease];
  
  return [testRunner runTests];
}

+ (BOOL)runTestables:(NSArray *)testables
             testSDK:(NSString *)testSDK
             options:(Options *)options
       xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  for (NSDictionary *testable in testables) {
    BOOL senTestInvertScope = [testable[@"senTestInvertScope"] boolValue];
    NSString *senTestList = testable[@"senTestList"];

    BOOL succeeded = [self runTestable:testable
                             reproters:options.implicitAction.reporters
                               objRoot:xcodeSubjectInfo.objRoot
                               symRoot:xcodeSubjectInfo.symRoot
                        xcodeArguments:[options.implicitAction commonXcodeBuildArgumentsIncludingSDK:NO]
                               testSDK:testSDK
                           senTestList:senTestList
                    senTestInvertScope:senTestInvertScope];
    if (!succeeded) {
      return NO;
    }
  }
  return YES;
}

@end
