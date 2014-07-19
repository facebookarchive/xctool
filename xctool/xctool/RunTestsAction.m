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
@property (nonatomic, assign) int logicTestBucketSize;
@property (nonatomic, assign) int appTestBucketSize;
@property (nonatomic, assign) BucketBy bucketBy;
@property (nonatomic, assign) int testTimeout;
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
                     description:@"SPEC is TARGET[:Class/case[,Class2/case2]]"
                       paramName:@"SPEC"
                           mapTo:@selector(addOnly:)],
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
    [Action actionOptionWithName:@"testTimeout"
                         aliases:nil
                     description:
     @"Force individual test cases to be killed after specified timeout."
                       paramName:@"N"
                           mapTo:@selector(setTestTimeout:)],
    ];
}

- (id)init
{
  if (self = [super init]) {
    _onlyList = [[NSMutableArray alloc] init];
    _logicTestBucketSize = 0;
    _appTestBucketSize = 0;
    _bucketBy = BucketByTestCase;
    _testTimeout = 0;
    _cpuType = CPU_TYPE_ANY;
  }
  return self;
}

- (void)dealloc
{
  [_testSDK release];
  [_onlyList release];
  [_deviceName release];
  [_OSVersion release];
  [super dealloc];
}

- (void)addOnly:(NSString *)argument
{
  [_onlyList addObject:argument];
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

- (NSArray *)onlyListAsTargetsAndSenTestList
{
  NSMutableArray *results = [NSMutableArray array];

  for (NSString *only in _onlyList) {
    NSRange colonRange = [only rangeOfString:@":"];
    NSString *target = nil;
    NSString *senTestList = nil;

    if (colonRange.length > 0) {
      target = [only substringToIndex:colonRange.location];
      senTestList = [only substringFromIndex:colonRange.location + 1];
    } else {
      target = only;
    }

    [results addObject:@{
     @"target": target,
     @"senTestList": senTestList ? senTestList : [NSNull null]
     }];
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
        _cpuType = CPU_TYPE_I386;
      } else {
        _cpuType = CPU_TYPE_X86_64;
      }
    }
    [self setDeviceName:destInfo[@"name"]];
    if (_deviceName) {
      _cpuType = [SimulatorInfo cpuTypeForDevice:_deviceName];
    }
    [self setOSVersion:destInfo[@"OS"]];
  }

  for (NSDictionary *only in [self onlyListAsTargetsAndSenTestList]) {
    if ([xcodeSubjectInfo testableWithTarget:only[@"target"]] == nil) {
      *errorMessage = [NSString stringWithFormat:@"run-tests: '%@' is not a testing target in this scheme.", only[@"target"]];
      return NO;
    }
  }

  return YES;
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  NSArray *testables = nil;

  if (_onlyList.count == 0) {
    // Use whatever we found in the scheme, except for skipped tests.
    NSMutableArray *unskipped = [NSMutableArray array];
    for (Testable *testable in xcodeSubjectInfo.testables) {
      if (!testable.skipped) {
        [unskipped addObject:testable];
      }
    }
    testables = unskipped;
  } else {
    // Munge the list of testables from the scheme to only include those given.
    NSMutableArray *newTestables = [NSMutableArray array];
    for (NSDictionary *only in [self onlyListAsTargetsAndSenTestList]) {
      Testable *matchingTestable = [xcodeSubjectInfo testableWithTarget:only[@"target"]];

      if (matchingTestable) {
        Testable *newTestable = [[matchingTestable copy] autorelease];

        if (only[@"senTestList"] != [NSNull null]) {
          newTestable.senTestList = only[@"senTestList"];
          newTestable.senTestInvertScope = NO;
        }

        [newTestables addObject:newTestable];
      }
    }
    testables = newTestables;
  }

  if (![self runTestables:testables
                  options:options
         xcodeSubjectInfo:xcodeSubjectInfo]) {
    return NO;
  }

  return YES;
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
    result[kReporter_BeginOCUnit_SDKNameKey] = action.OSVersion?:testableExecutionInfo.buildSettings[Xcode_SDK_NAME];
    result[kReporter_BeginOCUnit_BundleNameKey] = testableExecutionInfo.buildSettings[Xcode_FULL_PRODUCT_NAME];
    if (action.deviceName) {
      result[kReporter_BeginOCUnit_DeviceNameKey] = action.deviceName;
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
  return [[^(NSArray *reporters){
    PublishEventToReporters(reporters,
                            [[self class] eventForBeginOCUnitFromTestableExecutionInfo:testableExecutionInfo action:self]);

    PublishEventToReporters(reporters,
                            [[self class] eventForEndOCUnitFromTestableExecutionInfo:testableExecutionInfo
                                                                              action:self
                                                                           succeeded:succeeded
                                                                       failureReason:error]);
    return succeeded;
  } copy] autorelease];
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
  return [[^(NSArray *reporters) {
    OCUnitTestRunner *testRunner = [[[testRunnerClass alloc]
                                     initWithBuildSettings:testableExecutionInfo.buildSettings
                                     focusedTestCases:focusedTestCases
                                     allTestCases:allTestCases
                                     arguments:arguments
                                     environment:environment
                                     freshSimulator:_freshSimulator
                                     resetSimulator:_resetSimulator
                                     freshInstall:_freshInstall
                                     testTimeout:_testTimeout
                                     reporters:reporters] autorelease];
    [testRunner setCpuType:_cpuType];

    if ([testRunner isKindOfClass:[OCUnitIOSAppTestRunner class]]) {
      if (_deviceName) {
        [(OCUnitIOSAppTestRunner *)testRunner setDeviceName:_deviceName];
      }
      if (_OSVersion) {
        [(OCUnitIOSAppTestRunner *)testRunner setOSVersion:_OSVersion];
      }
    }
    if ([testRunner isKindOfClass:[OCUnitIOSLogicTestRunner class]]) {
      if (_OSVersion) {
        [(OCUnitIOSLogicTestRunner *)testRunner setOSVersion:_OSVersion];
      }
    }

    PublishEventToReporters(reporters,
                            [[self class] eventForBeginOCUnitFromTestableExecutionInfo:testableExecutionInfo action:self]);

    BOOL succeeded = [testRunner runTests];

    PublishEventToReporters(reporters,
                            [[self class] eventForEndOCUnitFromTestableExecutionInfo:testableExecutionInfo
                                                                              action:self
                                                                           succeeded:succeeded
                                                                       failureReason:nil]);

    return succeeded;
  } copy] autorelease];
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
      TestableExecutionInfo *info = [TestableExecutionInfo infoForTestable:testable
                                                          xcodeSubjectInfo:xcodeSubjectInfo
                                                       xcodebuildArguments:xcodebuildArguments
                                                                   testSDK:_testSDK
                                                                   cpuType:_cpuType];

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

  for (TestableExecutionInfo *info in testableExecutionInfos) {
    if (info.buildSettingsError) {
      TestableBlock block = [self blockToAdvertiseMessage:info.buildSettingsError
                                 forTestableExecutionInfo:info
                                                succeeded:NO];
      NSArray *annotatedBlock = @[block, info.testable.target];
      [blocksToRunOnDispatchQueue addObject:annotatedBlock];
      continue;
    }

    // array of [class, (bool) GC Enabled]
    Class testRunnerClass = [self testRunnerClassForBuildSettings:info.buildSettings];
    BOOL isApplicationTest = TestableSettingsIndicatesApplicationTest(info.buildSettings);

    NSArray *testCases = [OCUnitTestRunner filterTestCases:info.testCases
                                           withSenTestList:info.testable.senTestList
                                        senTestInvertScope:info.testable.senTestInvertScope];

    int bucketSize = isApplicationTest ? _appTestBucketSize : _logicTestBucketSize;
    NSArray *testChunks;

    if (_bucketBy == BucketByClass) {
      testChunks = BucketizeTestCasesByTestClass(testCases, bucketSize > 0 ? bucketSize : INT_MAX);
    } else if (_bucketBy == BucketByTestCase) {
      testChunks = BucketizeTestCasesByTestCase(testCases, bucketSize > 0 ? bucketSize : INT_MAX);
    } else {
      NSAssert(NO, @"Unexpected value for _bucketBy: %d", _bucketBy);
      abort();
    }

    int bucketCount = 1;

    for (NSArray *senTestListChunk in testChunks) {

      TestableBlock block;
      NSString *blockAnnotation;

      if (info.testCasesQueryError != nil) {
        block = [self blockToAdvertiseMessage:[NSString stringWithFormat:
                                             @"Failed to query the list of test cases in the test bundle: %@", info.testCasesQueryError]
                     forTestableExecutionInfo:info
                                    succeeded:NO];
        blockAnnotation = info.buildSettings[Xcode_FULL_PRODUCT_NAME];
      } else if (info.testCases.count == 0) {
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
      } else {
        block = [self blockForTestable:info.testable
                      focusedTestCases:senTestListChunk
                          allTestCases:info.testCases
                 testableExecutionInfo:info
                        testableTarget:info.testable.target
                     isApplicationTest:isApplicationTest
                             arguments:info.expandedArguments
                           environment:info.expandedEnvironment
                       testRunnerClass:testRunnerClass];
        blockAnnotation = [NSString stringWithFormat:@"%@ (bucket #%d, %ld tests)",
                           info.buildSettings[Xcode_FULL_PRODUCT_NAME],
                           bucketCount,
                           [senTestListChunk count]];
      }
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
  __block NSMutableArray *bundlesInProgress = [NSMutableArray array];

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
