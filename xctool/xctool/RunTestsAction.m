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
#import "OCUnitIOSAppTestRunner.h"
#import "OCUnitIOSDeviceTestRunner.h"
#import "OCUnitIOSLogicTestRunner.h"
#import "OCUnitOSXAppTestRunner.h"
#import "OCUnitOSXLogicTestRunner.h"
#import "OTestQuery.h"
#import "Options.h"
#import "ReporterEvents.h"
#import "ReportStatus.h"
#import "TaskUtil.h"
#import "XcodeSubjectInfo.h"
#import "XCToolUtil.h"

/// Break up an array into chunks of specified size
static NSArray *chunkifyArray(NSArray *array, NSUInteger chunkSize) {
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
    [Action actionOptionWithName:@"freshInstall"
                         aliases:nil
                     description:
     @"Use clean install of TEST_HOST for every app test run"
                         setFlag:@selector(setFreshInstall:)],
    [Action actionOptionWithName:@"parallelize"
                         aliases:nil
                     description:@"Parallelize execution of tests"
                         setFlag:@selector(setParallelize:)],
    [Action actionOptionWithName:@"bucketSize"
                         aliases:nil
                     description:@"Break test bundles in buckets of N test cases."
                       paramName:@"N"
                           mapTo:@selector(setBucketSize:)],
    [Action actionOptionWithName:@"simulator"
                         aliases:nil
                     description:@"Set simulator type (either iphone or ipad)"
                       paramName:@"SIMULATOR"
                           mapTo:@selector(setSimulatorType:)],
    ];
}

- (id)init
{
  if (self = [super init]) {
    self.onlyList = [NSMutableArray array];
    self->_bucketSize = 0;
  }
  return self;
}

- (void)dealloc {
  self.onlyList = nil;
  self.testSDK = nil;
  self.simulatorType = nil;
  [super dealloc];
}

- (void)addOnly:(NSString *)argument
{
  [self.onlyList addObject:argument];
}

- (void)setBucketSize:(NSString *)str
{
  _bucketSize = [str intValue];
}

- (NSArray *)onlyListAsTargetsAndSenTestList
{
  NSMutableArray *results = [NSMutableArray array];

  for (NSString *only in self.onlyList) {
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

  if (self.onlyList.count == 0) {
    // Use whatever we found in the scheme, except for skipped tests.
    NSMutableArray *unskipped = [NSMutableArray array];
    for (NSDictionary *testable in xcodeSubjectInfo.testables) {
      if (![testable[@"skipped"] boolValue]) {
        [unskipped addObject:testable];
      }
    }
    testables = unskipped;
  } else {
    // Munge the list of testables from the scheme to only include those given.
    NSMutableArray *newTestables = [NSMutableArray array];
    for (NSDictionary *only in [self onlyListAsTargetsAndSenTestList]) {
      NSDictionary *matchingTestable = [xcodeSubjectInfo testableWithTarget:only[@"target"]];

      if (matchingTestable) {
        NSMutableDictionary *newTestable = [NSMutableDictionary dictionaryWithDictionary:matchingTestable];

        if (only[@"senTestList"] != [NSNull null]) {
          newTestable[@"senTestList"] = only[@"senTestList"];
          newTestable[@"senTestInvertScope"] = @NO;
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

- (NSArray *)argumentsWithMacrosExpanded:(NSArray *)arr
                       fromBuildSettings:(NSDictionary *)settings
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:[arr count]];

  for (NSString *str in arr) {
    [result addObject:[[self class] stringWithMacrosExpanded:str
                                           fromBuildSettings:settings]];
  }

  return result;
}

- (NSDictionary *)enviornmentWithMacrosExpanded:(NSDictionary *)dict
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

+ (NSDictionary *)testableBuildSettingsForProject:(NSString *)projectPath
                                           target:(NSString *)target
                                          objRoot:(NSString *)objRoot
                                          symRoot:(NSString *)symRoot
                                sharedPrecompsDir:(NSString *)sharedPrecompsDir
                                   xcodeArguments:(NSArray *)xcodeArguments
                                          testSDK:(NSString *)testSDK
{
  // Collect build settings for this test target.
  NSTask *settingsTask = [[NSTask alloc] init];
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
 * @return Array on arrays in the form of: [test runner class, GC-enabled boolean]
 */
- (NSArray *)testConfigurationsForBuildSettings:(NSDictionary *)testableBuildSettings
{
  NSString *sdkName = testableBuildSettings[@"SDK_NAME"];
  BOOL isApplicationTest = testableBuildSettings[@"TEST_HOST"] != nil;
  
  // array of [class, (bool) GC Enabled]
  NSMutableArray *testConfigurations = [NSMutableArray array];
  
  if ([sdkName hasPrefix:@"iphonesimulator"]) {
    if (isApplicationTest) {
      [testConfigurations addObject:@[[OCUnitIOSAppTestRunner class], @NO]];
    } else {
      [testConfigurations addObject:@[[OCUnitIOSLogicTestRunner class], @NO]];
    }
  } else if ([sdkName hasPrefix:@"macosx"]) {
    Class testClass = {0};
    if (isApplicationTest) {
      testClass = [OCUnitOSXAppTestRunner class];
    } else {
      testClass = [OCUnitOSXLogicTestRunner class];
    }
    
    NSString *enableGC = testableBuildSettings[@"GCC_ENABLE_OBJC_GC"];
    
    if ([enableGC isEqualToString:@"required"]) {
      [testConfigurations addObject:@[testClass, @YES]];
    } else if ([enableGC isEqualToString:@"supported"]) {
      // If GC is marked as 'supported', Apple's normal unit-testing harness will run tests twice,
      // once with GC off and once with GC on.
      [testConfigurations addObject:@[testClass, @YES]];
      [testConfigurations addObject:@[testClass, @NO]];
    } else {
      [testConfigurations addObject:@[testClass, @NO]];
    }
  } else if ([sdkName hasPrefix:@"iphoneos"]) {
    [testConfigurations addObject:@[[OCUnitIOSDeviceTestRunner class], @NO]];
  } else {
    NSAssert(NO, @"Unexpected SDK: %@", sdkName);
  }

  return testConfigurations;
}

/**
 * Use otest-query-[ios|osx] to get a list of all SenTestCase classes in the
 * test bundle.
 */
+ (NSArray *)queryTestCasesWithBuildSettings:(NSDictionary *)testableBuildSettings
{
  NSString *sdkName = testableBuildSettings[@"SDK_NAME"];
  NSString *testBundlePath = [NSString stringWithFormat:@"%@/%@",
                              testableBuildSettings[@"BUILT_PRODUCTS_DIR"],
                              testableBuildSettings[@"FULL_PRODUCT_NAME"]];

  if ([sdkName hasPrefix:@"iphonesimulator"]) {
    return OTestQueryTestCasesInIOSBundle(testBundlePath, sdkName);
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
                                            disableGC);
  } else if ([sdkName hasPrefix:@"iphoneos"]) {
    // We can't run tests on device yet, but we must return a test list here or
    // we'll never get far enough to run OCUnitIOSDeviceTestRunner.
    return @[@"PlaceHolderForDeviceTests"];
  } else {
    NSAssert(NO, @"Unexpected SDK: %@", sdkName);
    abort();
  }
}

/**
 * Block used to run otest for a test bundle, with a specific test list.
 *
 * @param reporters An array of reporters to fire events to.
 * @return YES if tests ran and all passed.
 */
typedef BOOL (^TestableBlock)(NSArray *reporters);

- (TestableBlock)blockForTestable:(NSDictionary *)testable
                      senTestList:(NSString *)senTestList
            testableBuildSettings:(NSDictionary *)testableBuildSettings
                   testableTarget:(NSString *)testableTarget
                isApplicationTest:(BOOL)isApplicationTest
                        arguments:(NSArray *)arguments
                      environment:(NSDictionary *)environment
                  testRunnerClass:(Class)testRunnerClass
                        gcEnabled:(BOOL)garbageCollectionEnabled
{
  return [[^(NSArray *reporters) {
    OCUnitTestRunner *testRunner = [[[testRunnerClass alloc]
                                     initWithBuildSettings:testableBuildSettings
                                     senTestList:senTestList
                                     arguments:arguments
                                     environment:environment
                                     garbageCollection:garbageCollectionEnabled
                                     freshSimulator:self.freshSimulator
                                     freshInstall:self.freshInstall
                                     simulatorType:self.simulatorType
                                     reporters:reporters] autorelease];
    
    NSDictionary *commonEventInfo = @{kReporter_BeginOCUnit_BundleNameKey: testableBuildSettings[@"FULL_PRODUCT_NAME"],
                                      kReporter_BeginOCUnit_SDKNameKey: testableBuildSettings[@"SDK_NAME"],
                                      kReporter_BeginOCUnit_TestTypeKey: isApplicationTest ? @"application-test" : @"logic-test",
                                      kReporter_BeginOCUnit_GCEnabledKey: @(garbageCollectionEnabled),
                                      };
    
    NSMutableDictionary *beginEvent =
    [NSMutableDictionary dictionaryWithDictionary:@{@"event": kReporter_Events_BeginOCUnit}];
    [beginEvent addEntriesFromDictionary:commonEventInfo];
    PublishEventToReporters(reporters, beginEvent);
    
    NSString *error = nil;
    BOOL succeeded = [testRunner runTestsWithError:&error];

    NSMutableDictionary *endEvent = [NSMutableDictionary dictionaryWithDictionary:
                                     @{@"event": kReporter_Events_EndOCUnit,
                                                 kReporter_EndOCUnit_SucceededKey: @(succeeded),
                                             kReporter_EndOCUnit_FailureReasonKey: (error ? error : [NSNull null]),
                                     }];
    [endEvent addEntriesFromDictionary:commonEventInfo];
    PublishEventToReporters(reporters, endEvent);
    
    return succeeded;
  } copy] autorelease];
}

- (BOOL)runTestables:(NSArray *)testables
             options:(Options *)options
    xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  dispatch_queue_t q = dispatch_queue_create("xctool.runtests",
                                             self.parallelize ? DISPATCH_QUEUE_CONCURRENT
                                                              : DISPATCH_QUEUE_SERIAL);
  dispatch_group_t group = dispatch_group_create();

  // Limits the number of outstanding operations.
  // Note that the operation must not acquire this resources in one block and
  // release in another block submitted to the same queue, as it may lead to
  // starvation since the queue may not run the release block.
  dispatch_semaphore_t jobLimiter = dispatch_semaphore_create([[NSProcessInfo processInfo] processorCount]);

  NSMutableArray *blocksToRunOnMainThread = [NSMutableArray array];
  NSMutableArray *blocksToRunOnDispatchQueue = [NSMutableArray array];

  NSArray *xcodebuildArguments = [options commonXcodeBuildArgumentsForSchemeAction:@"TestAction"
                                                                  xcodeSubjectInfo:xcodeSubjectInfo];
  
  NSMutableDictionary *testableBuildSettings = [NSMutableDictionary dictionary];
  NSMutableDictionary *testableTestClasses = [NSMutableDictionary dictionary];
  NSMutableDictionary *testableArguments = [NSMutableDictionary dictionary];
  NSMutableDictionary *testableEnvironment = [NSMutableDictionary dictionary];
  
  ReportStatusMessageBegin(options.reporters, REPORTER_MESSAGE_INFO,
                           @"Collecting info for testables...");
  
  for (NSDictionary *testable in testables) {
    dispatch_group_async(group, q, ^{
      dispatch_semaphore_wait(jobLimiter, DISPATCH_TIME_FOREVER);
      
      NSString *testableProjectPath = testable[@"projectPath"];
      NSString *testableTarget = testable[@"target"];

      NSDictionary *buildSettings = [[self class] testableBuildSettingsForProject:testableProjectPath
                                                                           target:testableTarget
                                                                          objRoot:xcodeSubjectInfo.objRoot
                                                                          symRoot:xcodeSubjectInfo.symRoot
                                                                sharedPrecompsDir:xcodeSubjectInfo.sharedPrecompsDir
                                                                   xcodeArguments:xcodebuildArguments
                                                                          testSDK:_testSDK];
      
      NSArray *testClasses = [[self class] queryTestCasesWithBuildSettings:buildSettings];
      NSAssert(testClasses != nil, @"Can't query test case names.");
      
      NSArray *arguments = testable[@"arguments"];
      NSDictionary *environment = testable[@"environment"];

      // In Xcode, you can optionally include variables in your args or environment
      // variables.  i.e. "$(ARCHS)" gets transformed into "armv7".
      if ([testable[@"macroExpansionProjectPath"] isNotEqualTo:[NSNull null]]) {
        arguments = [self argumentsWithMacrosExpanded:arguments
                                    fromBuildSettings:buildSettings];
        environment = [self enviornmentWithMacrosExpanded:environment
                                        fromBuildSettings:buildSettings];
      }
      
      @synchronized(self) {
        testableBuildSettings[testable] = buildSettings;
        testableTestClasses[testable] = testClasses;
        testableArguments[testable] = arguments;
        testableEnvironment[testable] = environment;
      }
      
      dispatch_semaphore_signal(jobLimiter);
    });
  }
  
  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
  ReportStatusMessageEnd(options.reporters, REPORTER_MESSAGE_INFO,
                         @"Collecting info for testables...");
  
  for (NSDictionary *testable in testables) {
    // array of [class, (bool) GC Enabled]
    NSArray *testConfigurations = [self testConfigurationsForBuildSettings:testableBuildSettings[testable]];
    BOOL isApplicationTest = testableBuildSettings[testable][@"TEST_HOST"] != nil;
    
    NSArray *testCases = [OCUnitTestRunner filterTestCases:testableTestClasses[testable]
                                           withSenTestList:testable[@"senTestList"]
                                        senTestInvertScope:[testable[@"senTestInvertScope"] boolValue]];
    NSArray *testChunks = chunkifyArray(testCases,
                                        _bucketSize > 0 ? _bucketSize : INT_MAX);
    
    for (NSArray *testConfiguration in testConfigurations) {
      Class testRunnerClass = testConfiguration[0];
      BOOL garbageCollectionEnabled = [testConfiguration[1] boolValue];

      for (NSArray *senTestListChunk in testChunks) {
        
        NSString *senTestListString = [OCUnitTestRunner reduceSenTestListToBroadestForm:senTestListChunk
                                                                           allTestCases:testCases];
        
        TestableBlock block = [self blockForTestable:testable
                                         senTestList:senTestListString
                               testableBuildSettings:testableBuildSettings[testable]
                                      testableTarget:testable[@"target"]
                                   isApplicationTest:isApplicationTest
                                           arguments:testableArguments[testable]
                                         environment:testableEnvironment[testable]
                                     testRunnerClass:testRunnerClass
                                           gcEnabled:garbageCollectionEnabled];
        if (isApplicationTest) {
          [blocksToRunOnMainThread addObject:block];
        } else {
          [blocksToRunOnDispatchQueue addObject:block];
        }
      }
    }
  }
  
  __block BOOL succeeded = YES;
  
  void (^runTestableBlockAndSaveSuccess)(TestableBlock) = ^(TestableBlock block) {
    NSArray *reporters;
    
    if (_parallelize) {
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
      }
      
      succeeded &= blockSucceeded;
    }
  };
  
  for (TestableBlock block in blocksToRunOnDispatchQueue) {
    dispatch_group_async(group, q, ^{
      dispatch_semaphore_wait(jobLimiter, DISPATCH_TIME_FOREVER);
    
      runTestableBlockAndSaveSuccess(block);
      
      dispatch_semaphore_signal(jobLimiter);
    });
  }
  
  // If we're running in parallel, we can go ahead and start running the
  // application tests in serial while we're waiting on the parallelized
  // logic tests to finish.
  if (!_parallelize) {
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
  }
  
  for (TestableBlock block in blocksToRunOnMainThread) {
    runTestableBlockAndSaveSuccess(block);
  }
  
  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

  dispatch_release(group);
  dispatch_release(jobLimiter);
  dispatch_release(q);

  return succeeded;
}

@end
