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

#import <QuartzCore/QuartzCore.h>

#import "OCUnitTestRunner.h"
#import "OCUnitTestRunnerInternal.h"
#import "ReportStatus.h"
#import "TestRunState.h"
#import "XcodeBuildSettings.h"
#import "XCTestConfiguration.h"
#import "XCToolUtil.h"

static NSString * const kEnvVarPassThroughPrefix = @"XCTOOL_TEST_ENV_";

@interface OCUnitTestRunner ()
@property (nonatomic, copy) NSDictionary *buildSettings;
@property (nonatomic, copy) SimulatorInfo *simulatorInfo;
@property (nonatomic, copy) NSArray *focusedTestCases;
@property (nonatomic, copy) NSArray *allTestCases;
@property (nonatomic, copy) NSArray *arguments;
@property (nonatomic, copy) NSDictionary *environment;
@property (nonatomic, assign) BOOL garbageCollection;
@property (nonatomic, assign) BOOL freshSimulator;
@property (nonatomic, assign) BOOL resetSimulator;
@property (nonatomic, assign) BOOL newSimulatorInstance;
@property (nonatomic, assign) BOOL noResetSimulatorOnFailure;
@property (nonatomic, assign) BOOL freshInstall;
@property (nonatomic, copy, readwrite) NSArray *reporters;
@property (nonatomic, copy) NSDictionary *framework;
@property (nonatomic, copy) NSDictionary *processEnvironment;
@end

@implementation OCUnitTestRunner

/**
 * Helper to check if the string is a prefix wildcard string,
 * which is a string ending with a star character "*".
 * If this is the case, a string with the star character is returned, otherwise 'nil'
 *
 * @param specifier The string to check
 */
+ (NSString *)wildcardPrefixFrom:(NSString *)specifier {
  NSString *resultPrefix = nil;
  if ([specifier length] > 0 &&
      [specifier characterAtIndex:specifier.length-1] == '*') {
    resultPrefix = [specifier substringToIndex:specifier.length-1];
  }
  return resultPrefix;
}

+ (NSSet *)findMatches:(NSArray *)matches
                 inSet:(NSSet *)set
     notMatchedEntries:(NSArray **)notMatched
{
  NSMutableSet *matchingSet = [NSMutableSet set];
  NSMutableArray *notMatchedSpecifiers = [NSMutableArray array];

  for (NSString *specifier in matches) {
    BOOL matched = NO;

    // If we have a slash, assume it's in the form of "SomeClass/testMethod"
    BOOL hasClassAndMethod = [specifier rangeOfString:@"/"].length > 0;
    NSString *matchingPrefix = [self wildcardPrefixFrom:specifier];

    if (hasClassAndMethod && !matchingPrefix) {
      // "SomeClass/testMethod"
      // Use the set for a fast strict matching for this one test
      if ([set containsObject:specifier]) {
        [matchingSet addObject:specifier];
        matched = YES;
      }
    } else {
      // "SomeClass", or "SomeClassPrefix*", or "SomeClass/testPrefix*"
      if (!matchingPrefix) {
        // Regular case - strict matching, append "/" to limit results to all tests for this one class
        matchingPrefix = [specifier stringByAppendingString:@"/"];
      }

      for (NSString *testCase in set) {
        if ([testCase hasPrefix:matchingPrefix]) {
          [matchingSet addObject:testCase];
          matched = YES;
        }
      }
    }

    if (!matched) {
      [notMatchedSpecifiers addObject:specifier];
    }
  }

  if (notMatched) {
    *notMatched = notMatchedSpecifiers;
  }

  return matchingSet;
}

+ (NSArray *)filterTestCases:(NSArray *)allTestCases
               onlyTestCases:(NSArray *)onlyTestCases
            skippedTestCases:(NSArray *)skippedTestCases
                       error:(NSString **)error
{
  NSSet *originalSet = [NSSet setWithArray:allTestCases];
  NSMutableSet *resultSet = [NSMutableSet set];
  if (onlyTestCases.count > 0) {
    NSArray *notMatchedEntries = nil;
    NSSet *filtered = [self findMatches:onlyTestCases
                                  inSet:originalSet
                      notMatchedEntries:&notMatchedEntries];
    if (notMatchedEntries.count > 0) {
      *error = [NSString stringWithFormat:@"Test cases for the following test specifiers weren't found: %@.", [notMatchedEntries componentsJoinedByString:@", "]];
      return nil;
    }
    [resultSet unionSet:filtered];
  } else {
    [resultSet unionSet:originalSet];
  }

  NSSet *testCasesToSkip = [self findMatches:skippedTestCases inSet:resultSet notMatchedEntries:nil];
  [resultSet minusSet:testCasesToSkip];

  return [resultSet sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES]]];
}

- (instancetype)initWithBuildSettings:(NSDictionary *)buildSettings
                        simulatorInfo:(SimulatorInfo *)simulatorInfo
                     focusedTestCases:(NSArray *)focusedTestCases
                         allTestCases:(NSArray *)allTestCases
                            arguments:(NSArray *)arguments
                          environment:(NSDictionary *)environment
                       freshSimulator:(BOOL)freshSimulator
                       resetSimulator:(BOOL)resetSimulator
                 newSimulatorInstance:(BOOL)newSimulatorInstance
            noResetSimulatorOnFailure:(BOOL)noResetSimulatorOnFailure
                         freshInstall:(BOOL)freshInstall
                          testTimeout:(NSInteger)testTimeout
                            reporters:(NSArray *)reporters
                   processEnvironment:(NSDictionary *)processEnvironment
{
  if (self = [super init]) {
    _buildSettings = [buildSettings copy];
    _simulatorInfo = [simulatorInfo copy];
    _simulatorInfo.buildSettings = buildSettings;
    _focusedTestCases = [focusedTestCases copy];
    _allTestCases = [allTestCases copy];
    _arguments = [arguments copy];
    _environment = [environment copy];
    _freshSimulator = freshSimulator;
    _resetSimulator = resetSimulator;
    _newSimulatorInstance = newSimulatorInstance;
    _noResetSimulatorOnFailure = noResetSimulatorOnFailure;
    _freshInstall = freshInstall;
    _testTimeout = testTimeout;
    _reporters = [reporters copy];
    _framework = FrameworkInfoForTestBundleAtPath([_simulatorInfo productBundlePath]);
    _processEnvironment = [processEnvironment copy];
  }
  return self;
}


- (void)runTestsAndFeedOutputTo:(FdOutputLineFeedBlock)outputLineBlock
                   startupError:(NSString **)startupError
                    otherErrors:(NSString **)otherErrors
{
  // Subclasses will override this method.
}

- (BOOL)runTests
{
  BOOL allTestsPassed = YES;
  OCTestSuiteEventState *testSuiteState = nil;

  while (!testSuiteState || [[testSuiteState unstartedTests] count]) {
    TestRunState *testRunState;
    if (!testSuiteState) {
      testRunState = [[TestRunState alloc] initWithTests:_focusedTestCases reporters:_reporters];
      testSuiteState = testRunState.testSuiteState;
    } else {
      testRunState = [[TestRunState alloc] initWithTestSuiteEventState:testSuiteState];
    }

    FdOutputLineFeedBlock feedOutputToBlock = ^(int fd, NSString *line) {
      [testRunState parseAndHandleEvent:line];
    };

    NSString *runTestsError = nil;
    NSString *otherErrors = nil;

    [testRunState prepareToRun];

    [self runTestsAndFeedOutputTo:feedOutputToBlock
                     startupError:&runTestsError
                      otherErrors:&otherErrors];

    [testRunState didFinishRunWithStartupError:runTestsError otherErrors:otherErrors];

    allTestsPassed &= [testRunState allTestsPassed];

    // update focused test cases
    OCTestSuiteEventState *suiteState = [testRunState testSuiteState];
    NSArray *unstartedTests = [suiteState unstartedTests];
    NSMutableArray *unstartedTestCases = [[NSMutableArray alloc] initWithCapacity:[unstartedTests count]];
    [unstartedTests enumerateObjectsUsingBlock:^(OCTestEventState *obj, NSUInteger idx, BOOL *stop) {
      [unstartedTestCases addObject:[NSString stringWithFormat:@"%@/%@", obj.className, obj.methodName]];
    }];

    _focusedTestCases = unstartedTestCases;
  }


  return allTestsPassed;
}

- (NSMutableArray *)commonTestArguments
{
  // Add any argments that might have been specifed in the scheme.
  NSMutableArray *args = [_arguments ?: @[] mutableCopy];
  [args addObjectsFromArray:@[
    // Not sure exactly what this does...
    @"-NSTreatUnknownArgumentsAsOpen", @"NO",
    // Not sure exactly what this does...
    @"-ApplePersistenceIgnoreState", @"YES",
  ]];
  return args;
}

- (NSArray *)testCasesToSkip
{
  NSSet *focusedSet = [NSSet setWithArray:_focusedTestCases];
  NSSet *allSet = [NSSet setWithArray:_allTestCases];

  if ((TestableSettingsIndicatesApplicationTest(_buildSettings)) && [focusedSet isEqualToSet:allSet]) {
    return nil;
  } else {
    // When running a specific subset of tests, Xcode.app will always pass the
    // the list of excluded tests and enable the InvertScope option.
    //
    // There are two ways to make SenTestingKit or XCTest run a specific test.
    // Suppose you have a test bundle with 2 tests: 'Cls1/testA', 'Cls2/testB'.
    //
    // If you only wanted to run 'Cls1/testA', you could express that in 2 ways:
    //
    //   1) otest ... -SenTest Cls1/testA -SenTestInvertScope NO
    //   2) otest ... -SenTest Cls1/testB -SenTestInvertScope YES
    //
    // Xcode itself always uses #2.  And, for some reason, when using the Kiwi
    // testing framework, option #2 is the _ONLY_ way to run specific tests.
    //
    NSMutableSet *invertedSet = [NSMutableSet setWithSet:allSet];
    [invertedSet minusSet:focusedSet];

    return [[invertedSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
  }
}

- (NSArray *)testArgumentsWithSpecifiedTestsToRun
{
  NSArray *testCasesToSkip = [self testCasesToSkip];
  BOOL invertScope = testCasesToSkip ? YES : NO;
  NSMutableArray *args = [self commonTestArguments];

  // Optionally inverts whatever SenTest / XCTest would normally select.
  [args addObjectsFromArray:@[
    [@"-" stringByAppendingString:_framework[kTestingFrameworkInvertScopeKey]],
    invertScope ? @"YES" : @"NO",
  ]];

  if ([testCasesToSkip count] == 0) {
    // SenTest / XCTest is one of Self, All, None,
    // or TestClassName[/testCaseName][,TestClassName2]
    [args addObject:[@"-" stringByAppendingString:_framework[kTestingFrameworkFilterTestArgsKey]]];
    // Xcode.app will always pass 'All' when running all tests in an
    // application test bundle.
    [args addObject:testCasesToSkip ? @"" : @"All"];
  } else {
    NSString *testScope = [testCasesToSkip componentsJoinedByString:@","];
    NSString *testListFilePath = MakeTempFileWithPrefix([NSString stringWithFormat:@"otest_test_list_%@", HashForString(testScope)]);
    NSError *writeError = nil;
    BOOL writeResult;
    /*
     * Since number of test cases to skip or run is unlimited we need to pass them through a file
     * because length of a command line string is limited.
     *
     * In XCTest framework there is a built-in feature that allows us to do that:
     *   test configuration could be saved into a file in plist format path to which should be
     *   passed in arguments with `-XCTestScopeFile` option.
     *
     * In SenTesting framework there is no such built-in feature. Since we are injecting otest-shim
     *   library we could swizzle `+[SenTestProbe testScope]` method and return list of test cases
     *   to skip or run there. In that case we could read list of test cases from a file and that is
     *   what we are doing below using `-OTEST_TESTLIST_FILE` option.
     */
    if ([_framework[kTestingFrameworkFilterTestArgsKey] isEqual:@"XCTest"]) {
      testListFilePath = [testListFilePath stringByAppendingPathExtension:@"plist"];
      NSData *data = [NSPropertyListSerialization dataWithPropertyList:@{@"XCTestScope": @[testScope],
                                                                         @"XCTestInvertScope": @(invertScope),}
                                                                format:NSPropertyListXMLFormat_v1_0
                                                               options:0
                                                                 error:&writeError];
      NSAssert(data, @"Couldn't convert to property list format: %@, error: %@", testScope, writeError);
      writeResult = [data writeToFile:testListFilePath atomically:YES];
      NSAssert(writeResult, @"Couldn't save list of tests to run to a file at path %@", testListFilePath);
      [args addObjectsFromArray:@[
        @"-XCTestScopeFile", testListFilePath,
      ]];
    } else {
      writeResult = [testScope writeToFile:testListFilePath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
      NSAssert(writeResult, @"Couldn't save list of tests to run to a file at path %@; error: %@", testListFilePath, writeError);
      [args addObjectsFromArray:@[
        // in otest-shim we are swizzling `+[SenTestProbe testScope]` and
        // returning list of tests saved in the file specified below
        @"-OTEST_TESTLIST_FILE", testListFilePath,
        @"-OTEST_FILTER_TEST_ARGS_KEY", _framework[kTestingFrameworkFilterTestArgsKey],
        // it looks like `simctl` polute `NSUserDefaults` of SenTesting framework during
        // test querying and set `SenTest` value to `None`. That tells SenTesting
        // framework to skip test running and as a result swizzled in `otest-shim` method
        // isn't called. To force the framework to call it we are passing fake value
        // of `SenTest` and then returning real list of tests to run from that method.
        [@"-" stringByAppendingString:_framework[kTestingFrameworkFilterTestArgsKey]],
        @"XCTOOL_FAKE_LIST_OF_TESTS",
      ]];
    }
  }

  return args;
}

- (NSDictionary *)testEnvironmentWithSpecifiedTestConfiguration
{
  NSArray *testCasesToSkip = [self testCasesToSkip];

  Class XCTestConfigurationClass = NSClassFromString(@"XCTestConfiguration");
  NSAssert(XCTestConfigurationClass, @"XCTestConfiguration isn't available");

  XCTestConfiguration *configuration = [[XCTestConfigurationClass alloc] init];
  [configuration setProductModuleName:_buildSettings[Xcode_PRODUCT_MODULE_NAME]];
  [configuration setTestBundleURL:[NSURL fileURLWithPath:[_simulatorInfo productBundlePath]]];
  [configuration setTestsToSkip:[NSSet setWithArray:testCasesToSkip]];
  [configuration setReportResultsToIDE:NO];

  NSString *XCTestConfigurationFilename = [NSString stringWithFormat:@"%@-%@", _buildSettings[Xcode_PRODUCT_NAME], [configuration.sessionIdentifier UUIDString]];
  NSString *XCTestConfigurationFilePath = [MakeTempFileWithPrefix(XCTestConfigurationFilename) stringByAppendingPathExtension:@"xctestconfiguration"];
  if ([[NSFileManager defaultManager] fileExistsAtPath:XCTestConfigurationFilePath]) {
    [[NSFileManager defaultManager] removeItemAtPath:XCTestConfigurationFilePath error:nil];
  }
  if (![NSKeyedArchiver archiveRootObject:configuration toFile:XCTestConfigurationFilePath]) {
    NSAssert(NO, @"Couldn't archive XCTestConfiguration to file at path %@", XCTestConfigurationFilePath);
  }

  return @{
    @"XCTestConfigurationFilePath": XCTestConfigurationFilePath,
  };
}

- (NSDictionary *)_filteredProcessEnvironment
{
  NSMutableDictionary *filteredProcessEnv = [NSMutableDictionary dictionary];
  BOOL isMacOSX = [[_simulatorInfo simulatedSdkName] hasPrefix:@"macosx"];
  for (NSString *envVarName in _processEnvironment) {
    NSString *value = [_processEnvironment objectForKey:envVarName];
    if ([envVarName hasPrefix:kEnvVarPassThroughPrefix]) {
      // Pass through any environment variables with a special prefix, after
      // stripping the prefix from the name.
      [filteredProcessEnv setObject:value
                             forKey:[envVarName substringFromIndex:[kEnvVarPassThroughPrefix length]]];
    } else if (isMacOSX) {
      // OS X tests get the entire calling environment.
      [filteredProcessEnv setObject:value forKey:envVarName];
    }
  }
  return filteredProcessEnv;
}

- (NSMutableDictionary *)otestEnvironmentWithOverrides:(NSDictionary *)overrides
{
  NSMutableDictionary *env = [NSMutableDictionary dictionary];

  NSMutableDictionary *internalEnvironment = [NSMutableDictionary dictionary];
  if (_testTimeout > 0) {
    internalEnvironment[@"OTEST_SHIM_TEST_TIMEOUT"] = [@(_testTimeout) stringValue];
  }

  NSArray *layers = @[
    [self _filteredProcessEnvironment],
    // Any special environment vars set in the scheme.
    _environment ?: @{},
    // Internal environment that should be passed to xctool libs
    internalEnvironment,
    // Whatever values we need to make the test run at all for
    // ios/mac or logic/application tests.
    overrides,
  ];
  for (NSDictionary *layer in layers) {
    [layer enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop){
      if ([key isEqualToString:@"DYLD_INSERT_LIBRARIES"] ||
          [key isEqualToString:@"DYLD_FALLBACK_FRAMEWORK_PATH"]) {
        // It's possible that the scheme (or regular host environment) has its
        // own value for DYLD_INSERT_LIBRARIES.  In that case, we don't want to
        // stomp on it when insert otest-shim.
        NSString *existingVal = env[key];
        if (existingVal) {
          env[key] = [existingVal stringByAppendingFormat:@":%@", val];
        } else {
          env[key] = val;
        }
      } else {
        env[key] = val;
      }
    }];
  }

  return env;
}

@end
