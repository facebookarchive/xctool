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

#import "OTestQuery.h"
#import "TaskUtil.h"
#import "XcodeSubjectInfo.h"
#import "XCToolUtil.h"

@implementation TestableExecutionInfo

+ (instancetype)infoForTestable:(Testable *)testable
               xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
            xcodebuildArguments:(NSArray *)xcodebuildArguments
                        testSDK:(NSString *)testSDK
{
  TestableExecutionInfo *info = [[[TestableExecutionInfo alloc] init] autorelease];
  info.testable = testable;

  info.buildSettings = [[self class] testableBuildSettingsForProject:testable.projectPath
                                                              target:testable.target
                                                             objRoot:xcodeSubjectInfo.objRoot
                                                             symRoot:xcodeSubjectInfo.symRoot
                                                   sharedPrecompsDir:xcodeSubjectInfo.sharedPrecompsDir
                                                      xcodeArguments:xcodebuildArguments
                                                             testSDK:testSDK];

  NSString *otestQueryError = nil;
  NSArray *testCases = [[self class] queryTestCasesWithBuildSettings:info.buildSettings
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
                                   xcodeArguments:(NSArray *)xcodeArguments
                                          testSDK:(NSString *)testSDK
{
  // Collect build settings for this test target.
  NSTask *settingsTask = CreateTaskInSameProcessGroup();
  [settingsTask setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"]];

  if (testSDK) {
    // If we were given a test sdk, then force that.  Otherwise, xcodebuild will
    // default to the SDK set in the project/target.
    xcodeArguments = ArgumentListByOverriding(xcodeArguments, @"-sdk", testSDK);
  }

  [settingsTask setArguments:[xcodeArguments arrayByAddingObjectsFromArray:@[
                                                                             @"-project", projectPath,
                                                                             @"-target", target,
                                                                             [NSString stringWithFormat:@"OBJROOT=%@", objRoot],
                                                                             [NSString stringWithFormat:@"SYMROOT=%@", symRoot],
                                                                             [NSString stringWithFormat:@"SHARED_PRECOMPS_DIR=%@", sharedPrecompsDir],
                                                                             @"-showBuildSettings",
                                                                             ]]];

  [settingsTask setEnvironment:@{
                                 @"DYLD_INSERT_LIBRARIES" : [XCToolLibPath() stringByAppendingPathComponent:@"xcodebuild-fastsettings-shim.dylib"],
                                 @"SHOW_ONLY_BUILD_SETTINGS_FOR_TARGET" : target,
                                 }];

  NSDictionary *result = LaunchTaskAndCaptureOutput(settingsTask);
  [settingsTask release];
  settingsTask = nil;

  NSDictionary *allSettings = BuildSettingsFromOutput(result[@"stdout"]);
  NSAssert([allSettings count] == 1,
           @"Should only have build settings for a single target.");

  NSDictionary *testableBuildSettings = allSettings[target];
  NSAssert(testableBuildSettings != nil,
           @"Should have found build settings for target '%@'",
           target);

  return testableBuildSettings;
}

/**
 * Use otest-query-[ios|osx] to get a list of all SenTestCase classes in the
 * test bundle.
 */
+ (NSArray *)queryTestCasesWithBuildSettings:(NSDictionary *)testableBuildSettings
                                       error:(NSString **)error
{
  NSString *sdkName = testableBuildSettings[@"SDK_NAME"];
  NSString *testBundlePath = [NSString stringWithFormat:@"%@/%@",
                              testableBuildSettings[@"BUILT_PRODUCTS_DIR"],
                              testableBuildSettings[@"FULL_PRODUCT_NAME"]];

  // TEST_HOST will sometimes be wrapped in "quotes".
  NSString *testHostExecutablePath = [testableBuildSettings[@"TEST_HOST"]
                                      stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];

  if ([sdkName hasPrefix:@"iphonesimulator"]) {
    if (testHostExecutablePath) {
      return OTestQueryTestCasesInIOSBundleWithTestHost(testBundlePath, testHostExecutablePath, sdkName, error);
    } else {
      return OTestQueryTestCasesInIOSBundle(testBundlePath, sdkName, error);
    }
  } else if ([sdkName hasPrefix:@"macosx"]) {
    BOOL disableGC;

    NSString *gccEnableObjcGC = testableBuildSettings[@"GCC_ENABLE_OBJC_GC"];
    if ([gccEnableObjcGC isEqualToString:@"required"] ||
        [gccEnableObjcGC isEqualToString:@"supported"]) {
      disableGC = NO;
    } else {
      disableGC = YES;
    }

    return OTestQueryTestCasesInOSXBundle(testBundlePath,
                                          testableBuildSettings[@"BUILT_PRODUCTS_DIR"],
                                          disableGC,
                                          error);
  } else if ([sdkName hasPrefix:@"iphoneos"]) {
    // We can't run tests on device yet, but we must return a test list here or
    // we'll never get far enough to run OCUnitIOSDeviceTestRunner.
    return @[@"PlaceHolderForDeviceTests"];
  } else {
    NSAssert(NO, @"Unexpected SDK: %@", sdkName);
    abort();
  }
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
    [macroStr release];
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
