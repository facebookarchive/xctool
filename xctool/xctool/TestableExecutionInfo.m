//
// Copyright 2013 Facebook
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "TestableExecutionInfo.h"

#import "OCUnitIOSAppTestQueryRunner.h"
#import "OCUnitIOSLogicTestQueryRunner.h"
#import "OCUnitOSXAppTestQueryRunner.h"
#import "OCUnitOSXLogicTestQueryRunner.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"
#import "XcodeSubjectInfo.h"

@implementation TestableExecutionInfo

+ (instancetype)infoForTestable:(Testable *)testable
               xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
            xcodebuildArguments:(NSArray *)xcodebuildArguments
                        testSDK:(NSString *)testSDK
                        cpuType:(cpu_type_t)cpuType
{
  TestableExecutionInfo *info = [[TestableExecutionInfo alloc] init];
  info.testable = testable;

  NSString *buildSettingsError = nil;
  NSDictionary *buildSettings = [[self class] testableBuildSettingsForProject:testable.projectPath
                                                                       target:testable.target
                                                                      objRoot:xcodeSubjectInfo.objRoot
                                                                      symRoot:xcodeSubjectInfo.symRoot
                                                            sharedPrecompsDir:xcodeSubjectInfo.sharedPrecompsDir
                                                         targetedDeviceFamily:xcodeSubjectInfo.targetedDeviceFamily
                                                               xcodeArguments:xcodebuildArguments
                                                                      testSDK:testSDK
                                                                        error:&buildSettingsError];

  if (buildSettings) {
    info.buildSettings = buildSettings;
  } else {
    info.buildSettingsError = buildSettingsError;
    return info;
  }

  NSString *otestQueryError = nil;
  NSArray *testCases = [[self class] queryTestCasesWithBuildSettings:info.buildSettings
                                                             cpuType:cpuType
                                                               error:&otestQueryError];
  if (testCases) {
    info.testCases = testCases;
  } else {
    info.testCasesQueryError = otestQueryError;
  }

  // In Xcode, you can optionally include variables in your args or environment
  // variables.  i.e. "$(ARCHS)" gets transformed into "armv7".
  if (testable.macroExpansionProjectPath != nil) {
    info.expandedArguments = [self argumentsWithMacrosExpanded:testable.arguments
                                             fromBuildSettings:info.buildSettings];
    info.expandedEnvironment = [self enviornmentWithMacrosExpanded:testable.environment
                                    fromBuildSettings:info.buildSettings];
  } else {
    info.expandedArguments = testable.arguments;
    info.expandedEnvironment = testable.environment;
  }

  return info;
}

+ (NSDictionary *)testableBuildSettingsForProject:(NSString *)projectPath
                                           target:(NSString *)target
                                          objRoot:(NSString *)objRoot
                                          symRoot:(NSString *)symRoot
                                sharedPrecompsDir:(NSString *)sharedPrecompsDir
                             targetedDeviceFamily:(NSString *)targetedDeviceFamily
                                   xcodeArguments:(NSArray *)xcodeArguments
                                          testSDK:(NSString *)testSDK
                                            error:(NSString **)error
{
  // Collect build settings for this test target.
  NSTask *settingsTask = CreateTaskInSameProcessGroup();
  [settingsTask setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"]];

  if (testSDK) {
    // If we were given a test sdk, then force that.  Otherwise, xcodebuild will
    // default to the SDK set in the project/target.
    xcodeArguments = ArgumentListByOverriding(xcodeArguments, @"-sdk", testSDK);
  }

  // For Xcode 5, we can pass `test -showBuildSettings` to xcodebuild and get
  // build settings that are specific to the `test` action.  In previous versions,
  // there was only the `build` action.
  NSString *action = ToolchainIsXcode5OrBetter() ? @"test" : @"build";

  [settingsTask setArguments:[xcodeArguments arrayByAddingObjectsFromArray:@[
                                                                             @"-project", projectPath,
                                                                             @"-target", target,
                                                                             [NSString stringWithFormat:@"%@=%@", Xcode_OBJROOT, objRoot],
                                                                             [NSString stringWithFormat:@"%@=%@", Xcode_SYMROOT, symRoot],
                                                                             [NSString stringWithFormat:@"%@=%@", Xcode_SHARED_PRECOMPS_DIR, sharedPrecompsDir],
                                                                             [NSString stringWithFormat:@"%@=%@", Xcode_TARGETED_DEVICE_FAMILY, targetedDeviceFamily],
                                                                             action,
                                                                             @"-showBuildSettings",
                                                                             ]]];

  [settingsTask setEnvironment:@{
                                 @"DYLD_INSERT_LIBRARIES" : [XCToolLibPath() stringByAppendingPathComponent:@"xcodebuild-fastsettings-shim.dylib"],
                                 @"SHOW_ONLY_BUILD_SETTINGS_FOR_TARGET" : target,
                                 }];

  NSDictionary *output = LaunchTaskAndCaptureOutput(settingsTask,
                                                    [NSString stringWithFormat:@"running xcodebuild -showBuildSettings for '%@' target", target]);
  settingsTask = nil;

  NSDictionary *allSettings = BuildSettingsFromOutput(output[@"stdout"]);

  if ([allSettings count] > 1) {
    *error = @"Should only have build settings for a single target.";
    return nil;
  }

  if ([allSettings count] == 0) {
    *error = [NSString stringWithFormat:
              @"Unable to read build settings for target '%@'.  It's likely that the "
              @"scheme references a non-existent target.\n"
              @"\n"
              @"Output from `xcodebuild -showBuildSettings`:\n\n"
              @"STDOUT:\n"
              @"%@\n\n"
              @"STDERR:\n"
              @"%@\n\n",
              target,
              output[@"stdout"],
              output[@"stderr"]];
    return nil;
  }

  if (!allSettings[target]) {
    *error = [NSString stringWithFormat:@"Should have found build settings for target '%@'", target];
    return nil;
  }

  return allSettings[target];
}

/**
 * Use otest-query-[ios|osx] to get a list of all SenTestCase classes in the
 * test bundle.
 */
+ (NSArray *)queryTestCasesWithBuildSettings:(NSDictionary *)testableBuildSettings
                                     cpuType:(cpu_type_t)cpuType
                                       error:(NSString **)error
{
  NSString *sdkName = testableBuildSettings[Xcode_SDK_NAME];
  BOOL isApplicationTest = TestableSettingsIndicatesApplicationTest(testableBuildSettings);

  Class runnerClass = {0};
  if ([sdkName hasPrefix:@"macosx"]) {
    if (isApplicationTest) {
      runnerClass = [OCUnitOSXAppTestQueryRunner class];
    } else {
      runnerClass = [OCUnitOSXLogicTestQueryRunner class];
    }
  } else if ([sdkName hasPrefix:@"iphoneos"]) {
    // We can't run tests on device yet, but we must return a test list here or
    // we'll never get far enough to run OCUnitIOSDeviceTestRunner.
    return @[@"Placeholder/ForDeviceTests"];
  } else {
    if (isApplicationTest) {
      runnerClass = [OCUnitIOSAppTestQueryRunner class];
    } else {
      runnerClass = [OCUnitIOSLogicTestQueryRunner class];
    }
  }
  OCUnitTestQueryRunner *runner = [[runnerClass alloc] initWithBuildSettings:testableBuildSettings
                                                                  withCpuType:cpuType];
  return [runner runQueryWithError:error];
}

+ (NSString *)stringWithMacrosExpanded:(NSString *)str
                     fromBuildSettings:(NSDictionary *)settings
{
  NSMutableString *result = [NSMutableString stringWithString:str];

  [settings enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *val, BOOL *stop){
    NSString *macroStr = [[NSString alloc] initWithFormat:@"$(%@)", key];
    [result replaceOccurrencesOfString:macroStr
                            withString:val
                               options:0
                                 range:NSMakeRange(0, [result length])];
  }];

  return result;
}

+ (NSArray *)argumentsWithMacrosExpanded:(NSArray *)arr
                       fromBuildSettings:(NSDictionary *)settings
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:[arr count]];

  for (NSString *str in arr) {
    [result addObject:[[self class] stringWithMacrosExpanded:str
                                           fromBuildSettings:settings]];
  }

  return result;
}

+ (NSDictionary *)enviornmentWithMacrosExpanded:(NSDictionary *)dict
                              fromBuildSettings:(NSDictionary *)settings
{
  NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[dict count]];

  for (NSString *key in [dict allKeys]) {
    NSString *keyExpanded = [[self class] stringWithMacrosExpanded:key
                                                 fromBuildSettings:settings];
    NSString *valExpanded = [[self class] stringWithMacrosExpanded:dict[key]
                                                 fromBuildSettings:settings];
    result[keyExpanded] = valExpanded;
  }

  return result;
}


@end
