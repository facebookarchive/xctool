//
// Copyright 2004-present Facebook. All Rights Reserved.
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
#import "SimulatorInfo.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"
#import "XcodeSubjectInfo.h"

@implementation TestableExecutionInfo

+ (instancetype)infoForTestable:(Testable *)testable
                  buildSettings:(NSDictionary *)buildSettings
                  simulatorInfo:(SimulatorInfo *)simulatorInfo
{
  TestableExecutionInfo *info = [[TestableExecutionInfo alloc] init];
  info.testable = testable;
  info.buildSettings = buildSettings;
  info.simulatorInfo = simulatorInfo;
  info.simulatorInfo.buildSettings = buildSettings;

  NSString *otestQueryError = nil;
  NSArray *testCases = [[self class] queryTestCasesWithSimulatorInfo:info.simulatorInfo
                                                               error:&otestQueryError];
  if (testCases) {
    info.testCases = testCases;
  } else {
    info.testCasesQueryError = otestQueryError;
  }

  // In Xcode, you can optionally include variables in your args or environment
  // variables.  i.e. "$(ARCHS)" gets transformed into "armv7".
  if (testable.macroExpansionProjectPath != nil) {
    // Override any settings that are defined in the environment
    NSMutableDictionary *settingsAndProcessEnvironment = [info.buildSettings mutableCopy];
    [settingsAndProcessEnvironment addEntriesFromDictionary:[[NSProcessInfo processInfo] environment]];

    info.expandedArguments = [self argumentsWithMacrosExpanded:testable.arguments
                        fromBuildSettingsAndProcessEnvironment:settingsAndProcessEnvironment];
    info.expandedEnvironment = [self enviornmentWithMacrosExpanded:testable.environment
                            fromBuildSettingsAndProcessEnvironment:settingsAndProcessEnvironment];
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

  // For Xcode 6, we can pass `test -showBuildSettings` to xcodebuild and get
  // build settings that are specific to the `test` action.  But in Xcode 7
  // `-scheme` should be passed along with `test` action which isn't always
  // defined. So we are using `build` action which doesn't require to specify
  // scheme.
  NSString *action = ToolchainIsXcode7OrBetter() ? @"build" : @"test";

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
+ (NSArray *)queryTestCasesWithSimulatorInfo:(SimulatorInfo *)simulatorInfo
                                       error:(NSString **)error
{
  NSString *sdkName = simulatorInfo.buildSettings[Xcode_SDK_NAME];
  BOOL isApplicationTest = TestableSettingsIndicatesApplicationTest(simulatorInfo.buildSettings);

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
  OCUnitTestQueryRunner *runner = [[runnerClass alloc] initWithSimulatorInfo:simulatorInfo];
  return [runner runQueryWithError:error];
}

/**
 * Xcode 6.4 behavior:
 * $(KNOWN_MACRO) -> "MACRO_REPLACEMENT"
 * $KNOWN_MACRO -> "MACRO_REPLACEMENT"
 * $(UNKNOWN_MACRO) -> ""
 * $UNKNOWN_MACRO -> "$UNKNOWN_MACRO"
 */
+ (NSString *)stringWithMacrosExpanded:(NSString *)str
fromBuildSettingsAndProcessEnvironment:(NSDictionary *)settings
{
  NSMutableString *result = [NSMutableString stringWithString:str];
  NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:@"\\$\\(?(\\w+)\\)?"
                                                                    options:NSRegularExpressionCaseInsensitive
                                                                      error:nil];
  BOOL replaced = YES;
  while (replaced) {
    replaced = NO;
    NSArray *matches = [regex matchesInString:result options:0 range:NSMakeRange(0, result.length)];
    for (NSTextCheckingResult *match in matches) {
      NSRange macroRange = [match rangeAtIndex:1];
      if (macroRange.location == NSNotFound) {
        continue;
      }
      NSString *matchedKeyword = [result substringWithRange:macroRange];
      if (settings[matchedKeyword]) {
        [result replaceCharactersInRange:match.range withString:settings[matchedKeyword]];
        replaced = YES;
      } else if (match.range.length == macroRange.length + 3) {
        [result replaceCharactersInRange:match.range withString:@""];
        replaced = YES;
      }
      break;
    }
  }
  return result;
}

+ (NSArray *)argumentsWithMacrosExpanded:(NSArray *)arr
  fromBuildSettingsAndProcessEnvironment:(NSDictionary *)settings
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:[arr count]];

  for (NSString *str in arr) {
    [result addObject:[[self class] stringWithMacrosExpanded:str
                      fromBuildSettingsAndProcessEnvironment:settings]];
  }

  return result;
}

+ (NSDictionary *)enviornmentWithMacrosExpanded:(NSDictionary *)dict
         fromBuildSettingsAndProcessEnvironment:(NSDictionary *)settings
{
  NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[dict count]];

  for (NSString *key in [dict allKeys]) {
    NSString *keyExpanded = [[self class] stringWithMacrosExpanded:key
                            fromBuildSettingsAndProcessEnvironment:settings];
    NSString *valExpanded = [[self class] stringWithMacrosExpanded:dict[key]
                            fromBuildSettingsAndProcessEnvironment:settings];
    result[keyExpanded] = valExpanded;
  }

  return result;
}


@end
