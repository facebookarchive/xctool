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

#import "RunTestsAction.h"

#import "EventBuffer.h"
#import "EventGenerator.h"
#import "OCUnitIOSAppTestRunner.h"
#import "OCUnitIOSDeviceTestRunner.h"
#import "OCUnitIOSLogicTestRunner.h"
#import "OCUnitOSXAppTestRunner.h"
#import "OCUnitOSXLogicTestRunner.h"
#import "Options.h"
#import "ReportStatus.h"
#import "SimDevice.h"
#import "SimRuntime.h"
#import "SimulatorInfo.h"
#import "TestableExecutionInfo.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"
#import "XcodeSubjectInfo.h"

/// Break up an array into chunks of specified size
static NSArray *chunkifyArray(NSArray *array, NSUInteger chunkSize) {
  if (array.count == 0) {
    return @[@[]];
  }

  NSMutableArray *chunks = [NSMutableArray array];
  NSMutableArray *currentChunk = [NSMutableArray array];
  for (id chunk in array) {
    [currentChunk addObject:chunk];
    if (currentChunk.count >= chunkSize) {
      [chunks addObject:currentChunk];
      currentChunk = [NSMutableArray array];
    }
  }
  if (currentChunk.count > 0) {
    [chunks addObject:currentChunk];
  }
  return chunks;
}

static BOOL IsDirectory(NSString *path) {
  BOOL isDirectory = NO;
  BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
  return exists && isDirectory;
};

NSArray *BucketizeTestCasesByTestCase(NSArray *testCases, int bucketSize)
{
  return chunkifyArray(testCases, bucketSize);
}

NSArray *BucketizeTestCasesByTestClass(NSArray *testCases, int bucketSize)
{
  NSMutableArray *testClassNames = [NSMutableArray array];
  NSMutableDictionary *testCasesByClass = [NSMutableDictionary dictionary];

  for (NSString *classAndMethod in testCases) {
    NSString *className = [classAndMethod componentsSeparatedByString:@"/"][0];

    if (testCasesByClass[className] == nil) {
      testCasesByClass[className] = [NSMutableArray array];
      [testClassNames addObject:className];
    }

    [testCasesByClass[className] addObject:classAndMethod];
  }

  NSArray *testClassNamesChunked = chunkifyArray(testClassNames, bucketSize);

  NSMutableArray *result = [NSMutableArray array];

  for (NSArray *testClassNames in testClassNamesChunked) {
    NSMutableArray *testCasesForClasses = [NSMutableArray array];
    for (NSString *testClassName in testClassNames) {
      [testCasesForClasses addObjectsFromArray:testCasesByClass[testClassName]];
    }
    [result addObject:testCasesForClasses];
  }

  return result;
}

@interface RunTestsAction ()
@property (nonatomic, strong) SimulatorInfo *simulatorInfo;
@property (nonatomic, assign) int logicTestBucketSize;
@property (nonatomic, assign) int appTestBucketSize;
@property (nonatomic, assign) BucketBy bucketBy;
@property (nonatomic, assign) int testTimeout;
@property (nonatomic, strong) NSMutableArray *rawAppTestArgs;
@end

@implementation RunTestsAction

+ (NSString *)name
{
  return @"run-tests";
}

+ (NSArray *)options
{
  return
  @[
    [Action actionOptionWithName:@"test-sdk"
                         aliases:nil
                     description:@"SDK to test with"
                       paramName:@"SDK"
                           mapTo:@selector(setTestSDK:)],
    [Action actionOptionWithName:@"only"
                         aliases:nil
                     description:
     @"SPEC is TARGET[:Class/case[,Class2/case2]]; use * when specifying class or case prefix."
                       paramName:@"SPEC"
                           mapTo:@selector(addOnly:)],
    [Action actionOptionWithName:@"omit"
                         aliases:nil
                     description:
     @"SPEC is TARGET[:Class/case[,Class2/case2]]; use * when specifying class or case prefix."
                       paramName:@"SPEC"
                           mapTo:@selector(addOmit:)],
    [Action actionOptionWithName:@"freshSimulator"
                         aliases:nil
                     description:
     @"Start fresh simulator for each application test target"
                         setFlag:@selector(setFreshSimulator:)],
    [Action actionOptionWithName:@"resetSimulator"
                         aliases:nil
                     description:
     @"Reset simulator content and settings and restart it before running every app test run."
                         setFlag:@selector(setResetSimulator:)],
    [Action actionOptionWithName:@"newSimulatorInstance"
                         aliases:nil
                     description:
     @"Start new instance of simulator for each application test target."
                         setFlag:@selector(setNewSimulatorInstance:)],
    [Action actionOptionWithName:@"noResetSimulatorOnFailure"
                         aliases:nil
                     description:
     @"Do not reset simulator content and settings if running failed."
                         setFlag:@selector(setNoResetSimulatorOnFailure:)],
    [Action actionOptionWithName:@"freshInstall"
                         aliases:nil
                     description:
     @"Use clean install of TEST_HOST for every app test run"
                         setFlag:@selector(setFreshInstall:)],
    [Action actionOptionWithName:@"parallelize"
                         aliases:nil
                     description:@"Parallelize execution of tests"
                         setFlag:@selector(setParallelize:)],
    [Action actionOptionWithName:@"logicTestBucketSize"
                         aliases:nil
                     description:@"Break logic test bundles in buckets of N test cases."
                       paramName:@"N"
                           mapTo:@selector(setLogicTestBucketSizeValue:)],
    [Action actionOptionWithName:@"appTestBucketSize"
                         aliases:nil
                     description:@"Break app test bundles in buckets of N test cases."
                       paramName:@"N"
                           mapTo:@selector(setAppTestBucketSizeValue:)],
    [Action actionOptionWithName:@"bucketBy"
                         aliases:nil
                     description:@"Either 'case' (default) or 'class'."
                       paramName:@"BUCKETBY"
                           mapTo:@selector(setBucketByValue:)],
    [Action actionOptionWithName:@"failOnEmptyTestBundles"
                         aliases:nil
                     description:@"Fail when an empty test bundle was run."
                         setFlag:@selector(setFailOnEmptyTestBundles:)],
    [Action actionOptionWithName:@"listTestsOnly"
                         aliases:nil
                     description:@"Skip actual test running and list them only."
                         setFlag:@selector(setListTestsOnly:)],
    [Action actionOptionWithName:@"targetedDeviceFamily"
                         aliases:nil
                     description:@"Target specific type of simulator when running tests (1=iPhone, 2=iPad, 4=Apple Watch)"
                       paramName:@"FAMILY"
                           mapTo:@selector(setTargetedDeviceFamily:)],
    [Action actionOptionWithName:@"testTimeout"
                         aliases:nil
                     description:
     @"Force individual test cases to be killed after specified timeout."
                       paramName:@"N"
                           mapTo:@selector(setTestTimeoutValue:)],
    [Action actionOptionWithName:@"logicTest"
                         aliases:nil
                     description:@"Add a path to a logic test bundle to run"
                       paramName:@"BUNDLE"
                           mapTo:@selector(addLogicTest:)],
    [Action actionOptionWithName:@"appTest"
                         aliases:nil
                     description:@"Add a path to an app test bundle with the path to its host app"
                       paramName:@"BUNDLE:HOST_APP"
                           mapTo:@selector(addAppTest:)],
    [Action actionOptionWithName:@"waitForDebugger"
                         aliases:nil
                     description:@"Spawned test processes will wait for a debugger to be attached before invoking tests. With the pretty reporter, a message will be displayed with the PID to attach. With the plain reporter, it will just halt."
                         setFlag:@selector(setWaitForDebugger:)],
    ];
}

+ (NSArray *)_allTestablesForLogicTests:(NSArray *)logicTests
                               appTests:(NSDictionary *)appTests
                       xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  if (logicTests.count || appTests.count) {
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *logicTestBundle in logicTests) {
      Testable *testable = [[Testable alloc] init];
      testable.target = logicTestBundle;
      [result addObject:testable];
    }

    for (NSString *appTestBundle in appTests) {
      Testable *testable = [[Testable alloc] init];
      testable.target = appTestBundle;
      [result addObject:testable];
    }
    return result;
  } else if (xcodeSubjectInfo.testables) {
    return xcodeSubjectInfo.testables;
  } else {
    return nil;
  }
}

+ (Testable *)_matchingTestableForTarget:(NSString *)target
                              logicTests:(NSArray *)logicTests
                                appTests:(NSDictionary *)appTests
                        xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  for (NSString *logicTestBundle in logicTests) {
    if ([target isEqualToString:logicTestBundle]) {
      Testable *testable = [[Testable alloc] init];
      testable.target = logicTestBundle;
      return testable;
    }
  }

  for (NSString *appTestBundle in appTests) {
    if ([target isEqualToString:appTestBundle]) {
      Testable *testable = [[Testable alloc] init];
      testable.target = appTestBundle;
      return testable;
    }
  }

  return [xcodeSubjectInfo testableWithTarget:target];
}

+ (void)_populateTestableBuildSettings:(NSDictionary **)defaultTestableBuildSettings
        perTargetTestableBuildSettings:(NSDictionary **)perTargetTestableBuildSettings
                            logicTests:(NSArray *)logicTests
                              appTests:(NSDictionary *)appTests
                               sdkName:(NSString *)sdkName
                               sdkPath:(NSString *)sdkPath
                          platformPath:(NSString *)platformPath
                  targetedDeviceFamily:(NSString *)targetedDeviceFamily
{
  NSAssert(sdkName, @"Sdk name should be specified using -sdk option");
  NSAssert(sdkPath, @"Sdk path should be known");

  NSString *platformName = [[[platformPath lastPathComponent] stringByDeletingPathExtension] lowercaseString];

  *defaultTestableBuildSettings = @{
    Xcode_SDK_NAME: sdkName,
    Xcode_SDKROOT: sdkPath,
    Xcode_PLATFORM_DIR: platformPath,
    Xcode_PLATFORM_NAME: platformName,
    Xcode_TARGETED_DEVICE_FAMILY: targetedDeviceFamily ?: @"1", // Default to iPhone simulator
  };

  NSMutableDictionary *newPerTargetTestableBuildSettings = [NSMutableDictionary dictionary];
  for (NSString *logicTest in logicTests) {
    NSString *logicTestDirName = [logicTest stringByDeletingLastPathComponent];
    NSString *logicTestFileName = [logicTest lastPathComponent];
    newPerTargetTestableBuildSettings[logicTest] = @{
      Xcode_BUILT_PRODUCTS_DIR: logicTestDirName,
      Xcode_FULL_PRODUCT_NAME: logicTestFileName,
    };
  }

  for (NSString *appTest in appTests) {
    NSString *appTestDirName = [appTest stringByDeletingLastPathComponent];
    NSString *appTestFileName = [appTest lastPathComponent];
    NSString *testHostPath = appTests[appTest];
    newPerTargetTestableBuildSettings[appTest] = @{
      Xcode_BUILT_PRODUCTS_DIR: appTestDirName,
      Xcode_FULL_PRODUCT_NAME: appTestFileName,
      Xcode_TEST_HOST: testHostPath,
    };
  }
  *perTargetTestableBuildSettings = newPerTargetTestableBuildSettings;
}

- (instancetype)init
{
  if (self = [super init]) {
    _onlyList = [[NSMutableArray alloc] init];
    _omitList = [[NSMutableArray alloc] init];
    _logicTestBucketSize = 0;
    _appTestBucketSize = 0;
    _bucketBy = BucketByTestCase;
    _testTimeout = 0;
    _rawAppTestArgs = [[NSMutableArray alloc] init];
    _logicTests = [[NSMutableArray alloc] init];
    _appTests = [[NSMutableDictionary alloc] init];
  }
  return self;
}


- (void)addOnly:(NSString *)argument
{
  [_onlyList addObject:argument];
}

- (void)addOmit:(NSString *)argument
{
  [_omitList addObject:argument];
}

- (void)setLogicTestBucketSizeValue:(NSString *)str
{
  _logicTestBucketSize = [str intValue];
}

- (void)setAppTestBucketSizeValue:(NSString *)str
{
  _appTestBucketSize = [str intValue];
}

- (void)setBucketByValue:(NSString *)str
{
  if ([str isEqualToString:@"class"]) {
    _bucketBy = BucketByClass;
  } else {
    _bucketBy = BucketByTestCase;
  }
}

- (void)setTestTimeoutValue:(NSString *)str
{
  _testTimeout = [str intValue];
}

- (void)addLogicTest:(NSString *)argument
{
  [_logicTests addObject:[argument stringByStandardizingPath]];
}

- (void)addAppTest:(NSString *)argument
{
  [_rawAppTestArgs addObject:argument];
}

- (BOOL)testsPresentInOptions
{
  return (_logicTests.count > 0) || (_rawAppTestArgs.count > 0) || (_appTests.count > 0);
}

- (NSDictionary *)onlyListAsTargetsAndTestCasesList
{
  NSMutableDictionary *results = [NSMutableDictionary dictionary];
  for (NSString *item in _onlyList) {
    NSRange colonRange = [item rangeOfString:@":"];
    NSString *target = nil;
    NSMutableArray *testList = nil;
    if (colonRange.length > 0) {
      target = [item substringToIndex:colonRange.location];
      testList = [[[item substringFromIndex:colonRange.location + 1] componentsSeparatedByString:@","] mutableCopy];
    } else {
      target = item;
    }
    // Prefer applying the setting to the more specific list rather than the target
    // if multiple -only are specified and one is a target while the other is a list
    if (results[target] == nil || [results[target] isEqualTo:[NSNull null]]) {
      results[target] = testList ?: [NSNull null];
    } else if (testList != nil) {
      [results[target] addObjectsFromArray:testList];
    }
  }
  return results;
}

- (NSDictionary *)omitListAsTargetsAndTestCasesList
{
  NSMutableDictionary *results = [NSMutableDictionary dictionary];
  for (NSString *item in _omitList) {
    NSRange colonRange = [item rangeOfString:@":"];
    NSString *target = nil;
    NSMutableArray *testList = nil;
    if (colonRange.length > 0) {
      target = [item substringToIndex:colonRange.location];
      testList = [[[item substringFromIndex:colonRange.location + 1] componentsSeparatedByString:@","] mutableCopy];
    } else {
      target = item;
    }
    if (results[target] == nil) {
      results[target] = testList ?: [NSNull null];
    } else {
      if (testList == nil || [results[target] isEqualTo:[NSNull null]]) {
        results[target] = [NSNull null];
      } else {
        [results[target] addObjectsFromArray:testList];
      }
    }
  }
  return results;
}

- (BOOL)validateWithOptions:(Options *)options
           xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
               errorMessage:(NSString **)errorMessage
{
  if ([self testSDK] == nil && [options sdk] != nil) {
    // If specified test SDKs aren't provided, use whatever we got via -sdk.
    [self setTestSDK:[options sdk]];
  }

  _simulatorInfo = [[SimulatorInfo alloc] init];
  if ([options destination]) {

    // If the destination was supplied, pull out the device name
    NSString *destStr = [options destination];
    NSDictionary *destInfo = ParseDestinationString(destStr, errorMessage);

    // Make sure the destination string is formatted well.
    if (!destInfo) {
      return NO;
    }

    if (destInfo[@"arch"] != nil) {
      if ([destInfo[@"arch"] isEqual:@"i386"]) {
        [_simulatorInfo setCpuType:CPU_TYPE_I386];
      } else {
        [_simulatorInfo setCpuType:CPU_TYPE_X86_64];
      }
    }
    [_simulatorInfo setDeviceName:destInfo[@"name"]];
    [_simulatorInfo setOSVersion:destInfo[@"OS"]];
    if (destInfo[@"id"] != nil) {
      NSUUID *udid = [[NSUUID alloc] initWithUUIDString:destInfo[@"id"]];
      SimulatorInfo *simInfo = [SimulatorInfo new];
      SimDevice *device = [simInfo deviceWithUDID:udid];
      [_simulatorInfo setDeviceName:device.name];
      [_simulatorInfo setOSVersion:device.runtime.versionString];
      [_simulatorInfo setDeviceUDID:udid];
    }
  }

  for (NSString *logicTestPath in _logicTests) {
    if (!IsDirectory(logicTestPath)) {
      *errorMessage = [NSString stringWithFormat:@"run-tests: Logic test at path '%@' does not exist or is not a directory", logicTestPath];
      return NO;
    }
  }

  for (NSString *rawAppTestArg in _rawAppTestArgs) {
    NSRange colonRange = [rawAppTestArg rangeOfString:@":"];

    if (colonRange.location == NSNotFound || colonRange.location == 0) {
      *errorMessage = [NSString stringWithFormat:@"run-tests: -appTest must be in the form test-bundle:test-app"];
      return NO;
    }

    NSString *testBundle = [[rawAppTestArg substringToIndex:colonRange.location] stringByStandardizingPath];
    NSString *hostApp = [[rawAppTestArg substringFromIndex:colonRange.location + 1] stringByStandardizingPath];
    NSString *existingHostAppForTestBundle = _appTests[testBundle];

    if (existingHostAppForTestBundle) {
      *errorMessage = [NSString stringWithFormat:@"run-tests: The same test bundle '%@' cannot test more than one test host app (got '%@' and '%@')",
                                testBundle, existingHostAppForTestBundle, hostApp];
      return NO;
    }

    if (!IsDirectory(testBundle)) {
      *errorMessage = [NSString stringWithFormat:@"run-tests: Application test at path '%@' does not exist or is not a directory", testBundle];
      return NO;
    }
    BOOL isDirectory;
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:hostApp isDirectory:&isDirectory];
    if (!fileExists || isDirectory) {
      *errorMessage = [NSString stringWithFormat:@"run-tests: Application test host binary at path '%@' does not exist or is not a file", hostApp];
      return NO;
    }

    _appTests[testBundle] = hostApp;
  }

  if (_onlyList.count > 0 && _omitList.count > 0) {
    *errorMessage = @"run-tests: -only and -omit cannot both be specified.";
    return NO;
  }
  for (NSString *target in [self onlyListAsTargetsAndTestCasesList]) {
    if ([[self class] _matchingTestableForTarget:target
                                      logicTests:_logicTests
                                        appTests:_appTests
                                xcodeSubjectInfo:xcodeSubjectInfo] == nil) {
      *errorMessage = [NSString stringWithFormat:@"run-tests: '%@' is not a testing target in this scheme.", target];
      return NO;
    }
  }

  return YES;
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  NSArray *testables = nil;

  if (_onlyList.count == 0) {
    // Use whatever we found in the scheme, except for skipped tests in the scheme, and
    // tests omitted via the command line.
    NSMutableArray *unskipped = [NSMutableArray array];
    NSArray *allTestables = [[self class] _allTestablesForLogicTests:_logicTests
                                                            appTests:_appTests
                                                    xcodeSubjectInfo:xcodeSubjectInfo];
    NSDictionary *omit = [self omitListAsTargetsAndTestCasesList];
    for (Testable *testable in allTestables) {
      NSMutableArray *omitList = omit[testable.target];
      if (omitList != nil) {
        // Set tests omitted via command line as skipped.  Tests omitted via the scheme are
        // already set to skipped.
        if (testable.skipped || [omitList isKindOfClass:[NSNull class]]) {
          testable.skipped = true;
        } else {
          testable.skippedTests = [testable.skippedTests arrayByAddingObjectsFromArray:omitList];
        }
      }
      if (!testable.skipped) {
        [unskipped addObject:testable];
      }
    }
    testables = unskipped;
  } else {
    // Munge the list of testables from the scheme to only include those given.
    NSMutableArray *newTestables = [NSMutableArray array];
    NSDictionary *onlyTargets = [self onlyListAsTargetsAndTestCasesList];
    for (NSString *only in onlyTargets) {
      Testable *matchingTestable =
        [[self class] _matchingTestableForTarget:only
                                      logicTests:_logicTests
                                        appTests:_appTests
                                xcodeSubjectInfo:xcodeSubjectInfo];

      if (matchingTestable) {
        NSArray *onlyList = onlyTargets[only];
        if (![onlyList isKindOfClass:[NSNull class]]) {
          matchingTestable.onlyTests = onlyList;
        }
        [newTestables addObject:matchingTestable];
      }
    }
    testables = newTestables;
  }

  return [self runTestables:testables options:options xcodeSubjectInfo:xcodeSubjectInfo];
}

- (Class)testRunnerClassForBuildSettings:(NSDictionary *)testableBuildSettings
{
  NSString *sdkName = testableBuildSettings[Xcode_SDK_NAME];
  BOOL isApplicationTest = TestableSettingsIndicatesApplicationTest(testableBuildSettings);

  if ([sdkName hasPrefix:@"iphoneos"]) {
    return [OCUnitIOSDeviceTestRunner class];
  } else if ([sdkName hasPrefix:@"macosx"]) {
    if (isApplicationTest) {
      return [OCUnitOSXAppTestRunner class];
    } else {
      return [OCUnitOSXLogicTestRunner class];
    }
  } else {
    if (isApplicationTest) {
      return [OCUnitIOSAppTestRunner class];
    } else {
      return [OCUnitIOSLogicTestRunner class];
    }
  }
}

+ (NSDictionary *)commonOCUnitEventInfoFromTestableExecutionInfo:(TestableExecutionInfo *)testableExecutionInfo action:(RunTestsAction *)action
{
  NSMutableDictionary *result = [NSMutableDictionary dictionary];

  if (testableExecutionInfo.buildSettings) {
    BOOL isApplicationTest = TestableSettingsIndicatesApplicationTest(testableExecutionInfo.buildSettings);

    result[kReporter_BeginOCUnit_TestTypeKey] = isApplicationTest ? @"application-test" : @"logic-test";
    result[kReporter_BeginOCUnit_SDKNameKey] = [testableExecutionInfo.simulatorInfo simulatedSdkName] ?: testableExecutionInfo.buildSettings[Xcode_SDK_NAME];
    result[kReporter_BeginOCUnit_BundleNameKey] = testableExecutionInfo.buildSettings[Xcode_FULL_PRODUCT_NAME];
    if ([testableExecutionInfo.simulatorInfo simulatedDeviceInfoName]) {
      result[kReporter_BeginOCUnit_DeviceNameKey] = [testableExecutionInfo.simulatorInfo simulatedDeviceInfoName];
    }
  }

  result[kReporter_BeginOCUnit_TargetNameKey] = testableExecutionInfo.testable.target;

  return result;
}

+ (NSDictionary *)eventForBeginOCUnitFromTestableExecutionInfo:(TestableExecutionInfo *)testableExecutionInfo action:(RunTestsAction *)action
{
  return EventDictionaryWithNameAndContent(kReporter_Events_BeginOCUnit,
                                           [self commonOCUnitEventInfoFromTestableExecutionInfo:testableExecutionInfo action:action]);
}

+ (NSDictionary *)eventForEndOCUnitFromTestableExecutionInfo:(TestableExecutionInfo *)testableExecutionInfo
                                                      action:(RunTestsAction *)action
                                                   succeeded:(BOOL)succeeded
                                               failureReason:(NSString *)failureReason
{
  NSMutableDictionary *event =
  [NSMutableDictionary dictionaryWithDictionary:
   EventDictionaryWithNameAndContent(kReporter_Events_EndOCUnit,
  @{kReporter_EndOCUnit_SucceededKey: @(succeeded),
    kReporter_EndOCUnit_MessageKey: (failureReason ?: [NSNull null])})];
  [event addEntriesFromDictionary:[self commonOCUnitEventInfoFromTestableExecutionInfo:testableExecutionInfo action:action]];
  return event;
}

/**
 * Block used to run otest for a test bundle, with a specific test list.
 *
 * @param reporters An array of reporters to fire events to.
 * @return YES if tests ran and all passed.
 */
typedef BOOL (^TestableBlock)(NSArray *reporters);

/**
 * In some cases, we're not going to run the tests for this bundle, but we'd still
 * like to publish the usual begin-ocunit / end-ocunit events so that we have
 * a place to advertise errors.
 */
- (TestableBlock)blockToAdvertiseMessage:(NSString *)error
              forTestableExecutionInfo:(TestableExecutionInfo *)testableExecutionInfo
                             succeeded:(BOOL)succeeded
{
  return [^(NSArray *reporters){
    PublishEventToReporters(reporters,
                            [[self class] eventForBeginOCUnitFromTestableExecutionInfo:testableExecutionInfo action:self]);

    PublishEventToReporters(reporters,
                            [[self class] eventForEndOCUnitFromTestableExecutionInfo:testableExecutionInfo
                                                                              action:self
                                                                           succeeded:succeeded
                                                                       failureReason:error]);
    return succeeded;
  } copy];
}

- (TestableBlock)blockForTestable:(Testable *)testable
                 focusedTestCases:(NSArray *)focusedTestCases
                     allTestCases:(NSArray *)allTestCases
            testableExecutionInfo:(TestableExecutionInfo *)testableExecutionInfo
                   testableTarget:(NSString *)testableTarget
                isApplicationTest:(BOOL)isApplicationTest
                        arguments:(NSArray *)arguments
                      environment:(NSDictionary *)environment
                  testRunnerClass:(Class)testRunnerClass
{
  return [^(NSArray *reporters) {
    OCUnitTestRunner *testRunner = [[testRunnerClass alloc] initWithBuildSettings:testableExecutionInfo.buildSettings
                                                                    simulatorInfo:_simulatorInfo
                                                                 focusedTestCases:focusedTestCases
                                                                     allTestCases:allTestCases
                                                                        arguments:arguments
                                                                      environment:environment
                                                                   freshSimulator:_freshSimulator
                                                                   resetSimulator:_resetSimulator
                                                             newSimulatorInstance:_newSimulatorInstance
                                                        noResetSimulatorOnFailure:_noResetSimulatorOnFailure
                                                                     freshInstall:_freshInstall
                                                                  waitForDebugger:_waitForDebugger
                                                                      testTimeout:_testTimeout
                                                                        reporters:reporters
                                                               processEnvironment:[[NSProcessInfo processInfo] environment]];

    PublishEventToReporters(reporters,
                            [[self class] eventForBeginOCUnitFromTestableExecutionInfo:testableExecutionInfo action:self]);

    BOOL succeeded = [testRunner runTests];

    PublishEventToReporters(reporters,
                            [[self class] eventForEndOCUnitFromTestableExecutionInfo:testableExecutionInfo
                                                                              action:self
                                                                           succeeded:succeeded
                                                                       failureReason:nil]);

    return succeeded;
  } copy];
}

- (BOOL)runTestables:(NSArray *)testables
             options:(Options *)options
    xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  dispatch_queue_t q = dispatch_queue_create("xctool.runtests",
                                             _parallelize ? DISPATCH_QUEUE_CONCURRENT
                                                          : DISPATCH_QUEUE_SERIAL);
  dispatch_group_t group = dispatch_group_create();

  // Limits the number of simultaneously existing threads.
  //
  // There is a dispatch thread soft limit on OS X (and iOS) which is equal to 64.
  // This limit shouldn't be reached because created threads could create additional
  // threads, for example, when interacting with CoreSimulator framework, and cause
  // deadlock if the limit is reached.
  //
  // Note that the operation must not acquire this resources in one block and
  // release in another block submitted to the same queue, as it may lead to
  // starvation since the queue may not run the release block.
  dispatch_semaphore_t queueLimiter = dispatch_semaphore_create([[NSProcessInfo processInfo] processorCount]);

  NSMutableArray *blocksToRunOnMainThread = [NSMutableArray array];
  NSMutableArray *blocksToRunOnDispatchQueue = [NSMutableArray array];

  NSArray *xcodebuildArguments = [options commonXcodeBuildArgumentsForSchemeAction:@"TestAction"
                                                                  xcodeSubjectInfo:xcodeSubjectInfo];

  NSMutableArray *testableExecutionInfos = [NSMutableArray array];

  ReportStatusMessageBegin(options.reporters, REPORTER_MESSAGE_INFO,
                           @"Collecting info for testables...");

  for (Testable *testable in testables) {
    dispatch_semaphore_wait(queueLimiter, DISPATCH_TIME_FOREVER);
    dispatch_group_async(group, q, ^{

      NSDictionary *testableBuildSettings = nil;
      NSString *buildSettingsError = nil;
      // Skip discovering test settings from Xcode if -logicTests or -appTests are passed.
      if ([self testsPresentInOptions]) {
        NSDictionary *defaultTestableBuildSettings = nil;
        NSDictionary *perTargetTestableBuildSettings = nil;
        [[self class] _populateTestableBuildSettings:&defaultTestableBuildSettings
                      perTargetTestableBuildSettings:&perTargetTestableBuildSettings
                                          logicTests:_logicTests
                                            appTests:_appTests
                                             sdkName:options.sdk
                                             sdkPath:options.sdkPath
                                        platformPath:options.platformPath
                                targetedDeviceFamily:_targetedDeviceFamily];
        NSMutableDictionary *settings = [defaultTestableBuildSettings mutableCopy];
        [settings addEntriesFromDictionary:perTargetTestableBuildSettings[testable.target]];
        testableBuildSettings = settings;
      } else {
        testableBuildSettings = [TestableExecutionInfo
            testableBuildSettingsForProject:testable.projectPath
                                     target:testable.target
                                    objRoot:xcodeSubjectInfo.objRoot
                                    symRoot:xcodeSubjectInfo.symRoot
                          sharedPrecompsDir:xcodeSubjectInfo.sharedPrecompsDir
                       targetedDeviceFamily:xcodeSubjectInfo.targetedDeviceFamily
                             xcodeArguments:xcodebuildArguments
                                    testSDK:_testSDK
                                      error:&buildSettingsError];
      }
      TestableExecutionInfo *info;
      if (testableBuildSettings) {
        info = [TestableExecutionInfo infoForTestable:testable
                                        buildSettings:testableBuildSettings
                                        simulatorInfo:_simulatorInfo];
      } else {
        info = [[TestableExecutionInfo alloc] init];
        info.testable = testable;
        info.buildSettingsError = buildSettingsError ?: @"Unknown build settings error";
      }
      @synchronized (self) {
        [testableExecutionInfos addObject:info];
      }

      dispatch_semaphore_signal(queueLimiter);
    });
  }

  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
  ReportStatusMessageEnd(options.reporters, REPORTER_MESSAGE_INFO,
                         @"Collecting info for testables...");

  if (_listTestsOnly) {
    return [self listTestsInTestableExecutionInfos:testableExecutionInfos options:options];
  }

  [xcodeSubjectInfo.actionScripts preTestWithOptions:options];

  for (TestableExecutionInfo *info in testableExecutionInfos) {
    if (info.buildSettingsError) {
      TestableBlock block = [self blockToAdvertiseMessage:info.buildSettingsError
                                 forTestableExecutionInfo:info
                                                succeeded:NO];
      NSArray *annotatedBlock = @[block, info.testable.target];
      [blocksToRunOnDispatchQueue addObject:annotatedBlock];
      continue;
    }

    if (info.testable.skipped) {
      NSString *message = [NSString stringWithFormat:@"skipping: This test bundle is disabled in %@ scheme.\n", xcodeSubjectInfo.subjectScheme];
      TestableBlock block = [self blockToAdvertiseMessage:message
                                 forTestableExecutionInfo:info
                                                succeeded:YES];
      NSArray *annotatedBlock = @[block, info.testable.target];
      [blocksToRunOnDispatchQueue addObject:annotatedBlock];
      continue;
    }

    if (info.testCasesQueryError != nil) {
      NSString *message = [NSString stringWithFormat:@"Failed to query the list of test cases in the test bundle: %@", info.testCasesQueryError];
      TestableBlock block = [self blockToAdvertiseMessage:message
                                 forTestableExecutionInfo:info
                                                succeeded:NO];
      NSString *blockAnnotation = info.buildSettings[Xcode_FULL_PRODUCT_NAME];
      NSArray *annotatedBlock = @[block, blockAnnotation];
      [blocksToRunOnDispatchQueue addObject:annotatedBlock];
      continue;
    }

    if (info.testCases.count == 0) {
      TestableBlock block;
      NSString *blockAnnotation;
      if (_failOnEmptyTestBundles) {
        block = [self blockToAdvertiseMessage:@"This test bundle contained no tests. Treating as a failure since -failOnEmpyTestBundles is enabled.\n"
                     forTestableExecutionInfo:info
                                    succeeded:NO];
        blockAnnotation = info.buildSettings[Xcode_FULL_PRODUCT_NAME];
      } else {
        block = [self blockToAdvertiseMessage:@"skipping: This test bundle contained no tests.\n"
                     forTestableExecutionInfo:info
                                    succeeded:YES];
        blockAnnotation = info.buildSettings[Xcode_FULL_PRODUCT_NAME];
      }
      NSArray *annotatedBlock = @[block, blockAnnotation];
      [blocksToRunOnDispatchQueue addObject:annotatedBlock];
      continue;
    }

    NSString *filterError = nil;
    NSArray *testCases = [OCUnitTestRunner filterTestCases:info.testCases
                                             onlyTestCases:info.testable.onlyTests
                                          skippedTestCases:info.testable.skippedTests
                                                     error:&filterError];
    if (testCases == nil) {
      TestableBlock block = [self blockToAdvertiseMessage:filterError
                                 forTestableExecutionInfo:info
                                                succeeded:NO];
      NSArray *annotatedBlock = @[block, info.testable.target];
      [blocksToRunOnDispatchQueue addObject:annotatedBlock];
      continue;
    } else if (testCases.count == 0) {
      NSString *message = [NSString stringWithFormat:@"skipping: No test cases to run or all test cases were skipped.\n"];
      TestableBlock block = [self blockToAdvertiseMessage:message
                                 forTestableExecutionInfo:info
                                                succeeded:YES];
      NSArray *annotatedBlock = @[block, info.testable.target];
      [blocksToRunOnDispatchQueue addObject:annotatedBlock];
      continue;
    }

    Class testRunnerClass = [self testRunnerClassForBuildSettings:info.buildSettings];
    BOOL isApplicationTest = TestableSettingsIndicatesApplicationTest(info.buildSettings);
    int bucketSize = isApplicationTest ? _appTestBucketSize : _logicTestBucketSize;
    NSArray *testChunks;

    if (_bucketBy == BucketByClass) {
      testChunks = BucketizeTestCasesByTestClass(testCases, bucketSize > 0 ? bucketSize : INT_MAX);
    } else if (_bucketBy == BucketByTestCase) {
      testChunks = BucketizeTestCasesByTestCase(testCases, bucketSize > 0 ? bucketSize : INT_MAX);
    } else {
      NSAssert(NO, @"Unexpected value for _bucketBy: %ld", _bucketBy);
      abort();
    }

    int bucketCount = 1;

    for (NSArray *testListChunk in testChunks) {
      TestableBlock block = [self blockForTestable:info.testable
                                  focusedTestCases:testListChunk
                                      allTestCases:info.testCases
                             testableExecutionInfo:info
                                    testableTarget:info.testable.target
                                 isApplicationTest:isApplicationTest
                                         arguments:info.expandedArguments
                                       environment:info.expandedEnvironment
                                   testRunnerClass:testRunnerClass];
      NSString *blockAnnotation = [NSString stringWithFormat:@"%@ (bucket #%d, %ld tests)", info.buildSettings[Xcode_FULL_PRODUCT_NAME], bucketCount, testListChunk.count];
      NSArray *annotatedBlock = @[block, blockAnnotation];

      if (isApplicationTest) {
        [blocksToRunOnMainThread addObject:annotatedBlock];
      } else {
        [blocksToRunOnDispatchQueue addObject:annotatedBlock];
      }

      bucketCount++;
    }
  }

  __block BOOL succeeded = YES;
  __weak NSMutableArray *bundlesInProgress = [NSMutableArray array];

  void (^runTestableBlockAndSaveSuccess)(TestableBlock, NSString *) = ^(TestableBlock block, NSString *blockAnnotation) {
    NSArray *reporters;

    if (_parallelize) {
      @synchronized (self) {
        [bundlesInProgress addObject:blockAnnotation];
        ReportStatusMessage(options.reporters, REPORTER_MESSAGE_INFO, @"Starting %@", blockAnnotation);
      }
      // Buffer reporter output, and we'll make sure it gets flushed serially
      // when the block is done.
      reporters = [EventBuffer wrapSinks:options.reporters];
    } else {
      reporters = options.reporters;
    }

    BOOL blockSucceeded = block(reporters);

    @synchronized (self) {
      if (_parallelize) {
        [reporters makeObjectsPerformSelector:@selector(flush)];

        [bundlesInProgress removeObject:blockAnnotation];
        if ([bundlesInProgress count] > 0) {
          ReportStatusMessage(options.reporters, REPORTER_MESSAGE_INFO, @"In Progress [%@]", [bundlesInProgress componentsJoinedByString:@", "]);
        }
      }

      succeeded &= blockSucceeded;
    }
  };

  for (NSArray *annotatedBlock in blocksToRunOnDispatchQueue) {
    dispatch_semaphore_wait(queueLimiter, DISPATCH_TIME_FOREVER);
    dispatch_group_async(group, q, ^{
      TestableBlock block = annotatedBlock[0];
      NSString *blockAnnotation = annotatedBlock[1];
      runTestableBlockAndSaveSuccess(block, blockAnnotation);

      dispatch_semaphore_signal(queueLimiter);
    });
  }

  // Wait for logic tests to finish before we start running simulator tests.
  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

  // Resetting `_parallelize` value while running applicaiton tests.
  //
  // Application tests are run serially on the main thread so parallelize option
  // will affect only the way reporters are notified about current status and
  // test results. If parallelize is YES then reporters won't print anything to
  // output until `block` is completed. If there is a deadlocking tests in the test
  // suite then only `[INFO] Starting <TestSuite>` will be printed w/o specifying
  // which test is actually locking test running.
  BOOL originalParallelizeValue = _parallelize;
  _parallelize = NO;

  for (NSArray *annotatedBlock in blocksToRunOnMainThread) {
    TestableBlock block = annotatedBlock[0];
    NSString *blockAnnotation = annotatedBlock[1];
    runTestableBlockAndSaveSuccess(block, blockAnnotation);
  }

  // Restore `_parallelize` value.
  _parallelize = originalParallelizeValue;

  dispatch_release(group);
  dispatch_release(queueLimiter);
  dispatch_release(q);

  [xcodeSubjectInfo.actionScripts postTestWithOptions:options];

  return succeeded;
}

- (BOOL)listTestsInTestableExecutionInfos:(NSArray *)testableExecutionInfos
                                  options:(Options *)options
{
  for (TestableExecutionInfo *testableExecutionInfo in testableExecutionInfos) {
    PublishEventToReporters(options.reporters,
                            [[self class] eventForBeginOCUnitFromTestableExecutionInfo:testableExecutionInfo action:self]);

    for (NSString *testCase in testableExecutionInfo.testCases) {
      NSArray *components = [testCase componentsSeparatedByString:@"/"];
      NSString *className = components[0];
      NSString *methodName = components[1];
      NSString *testName = [NSString stringWithFormat:@"-[%@ %@]", className, methodName];
      NSDictionary *beginTestEvent = @{kReporter_BeginTest_TestKey: testName,
                                       kReporter_BeginTest_ClassNameKey: className,
                                       kReporter_BeginTest_MethodNameKey: methodName};
      PublishEventToReporters(options.reporters,
                              EventDictionaryWithNameAndContent(kReporter_Events_BeginTest, beginTestEvent));


      NSDictionary *endTestEvent = @{kReporter_EndTest_TestKey: testName,
                                     kReporter_EndTest_ClassNameKey: className,
                                     kReporter_EndTest_MethodNameKey: methodName,
                                     kReporter_EndTest_SucceededKey: @"1",
                                     kReporter_EndTest_ResultKey: @"success",
                                     kReporter_EndTest_TotalDurationKey: @"0"};
      PublishEventToReporters(options.reporters,
                              EventDictionaryWithNameAndContent(kReporter_Events_EndTest, endTestEvent));
    }

    PublishEventToReporters(options.reporters,
                            [[self class] eventForEndOCUnitFromTestableExecutionInfo:testableExecutionInfo
                                                                              action:self
                                                                           succeeded:YES
                                                                       failureReason:nil]);
  }
  return YES;
}

@end
