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

#import "BufferedReporter.h"
#import "OCUnitIOSAppTestRunner.h"
#import "OCUnitIOSDeviceTestRunner.h"
#import "OCUnitIOSLogicTestRunner.h"
#import "OCUnitOSXAppTestRunner.h"
#import "OCUnitOSXLogicTestRunner.h"
#import "Options.h"
#import "Reporter.h"
#import "TaskUtil.h"
#import "XcodeSubjectInfo.h"
#import "XCToolUtil.h"

@interface TestableExecution : NSObject
@property (nonatomic, retain) NSArray *blocks;
@property (nonatomic, copy) BOOL(^completionBlock)();
@property (nonatomic, assign) BOOL mustRunInMainThread;
@end

@implementation TestableExecution

- (instancetype)initWithBlocks:(NSArray *)blocks
               completionBlock:(BOOL(^)())completionBlock
           mustRunInMainThread:(BOOL)mustRunInMainThread
{
  if (self = [super init]) {
    self.blocks = blocks;
    self.completionBlock = completionBlock;
    self.mustRunInMainThread = mustRunInMainThread;
  }
  return self;
}

- (void)runAsyncInQueue:(dispatch_queue_t)queue
                limiter:(dispatch_semaphore_t)limiter
             onComplete:(void(^)(BOOL))callback
{
  NSAssert(!self.mustRunInMainThread, @"must be async runnable");

  dispatch_group_t g = dispatch_group_create();
  dispatch_group_enter(g);

  for (void(^block)() in self.blocks) {
    dispatch_group_async(g, queue, ^{
      dispatch_semaphore_wait(limiter, DISPATCH_TIME_FOREVER);
      block();
      dispatch_semaphore_signal(limiter);
    });
  }
  dispatch_group_notify(g, queue, ^{
    BOOL succeeded = self.completionBlock();
    callback(succeeded);
  });

  dispatch_group_leave(g);
  dispatch_release(g);
}

- (BOOL)runSync
{
  for (BOOL(^block)() in self.blocks) {
    block();
  }
  return self.completionBlock();
}

@end


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
                     description:@"Parallelize execution of logic tests"
                         setFlag:@selector(setParallelize:)],
    [Action actionOptionWithName:@"parallelizeSuites"
                         aliases:nil
                     description:@"Parallelize test class execution within each target if > 0"
                       paramName:@"CHUNK_SIZE"
                           mapTo:@selector(setParallelizeChunkSize:)],
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
    self->_parallelizeChunkSize = 0;
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

- (void)setParallelizeChunkSize:(NSString *)str
{
  _parallelizeChunkSize = [str intValue];
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

/*!
 Retrieves build params and create execution objects for each configuration.

 @return TestableExecutions
         - kTestableBlocks: array of blocks returning BOOL for test-success
         - kTestableMustRunInMainThread: BOOL for tests that cannot be async
         - kTestableCompletionBlock: block to run after the test blocks have ran
 */
- (NSArray *)executionsForTestable:(NSDictionary *)testable
                         reporters:(NSArray *)rawReporters
                           objRoot:(NSString *)objRoot
                           symRoot:(NSString *)symRoot
                 sharedPrecompsDir:(NSString *)sharedPrecompsDir
                    xcodeArguments:(NSArray *)xcodeArguments
                       senTestList:(NSString *)senTestList
                senTestInvertScope:(BOOL)senTestInvertScope
{
  NSString *testableProjectPath = testable[@"projectPath"];
  NSString *testableTarget = testable[@"target"];

  // Collect build settings for this test target.
  NSTask *settingsTask = [[NSTask alloc] init];
  [settingsTask setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"]];

  if (_testSDK) {
    // If we were given a test sdk, then force that.  Otherwise, xcodebuild will
    // default to the SDK set in the project/target.
    xcodeArguments = ArgumentListByOverriding(xcodeArguments, @"-sdk", _testSDK);
  }

  [settingsTask setArguments:[xcodeArguments arrayByAddingObjectsFromArray:@[
                                                                             @"-project", testableProjectPath,
                                                                             @"-target", testableTarget,
                                                                             [NSString stringWithFormat:@"OBJROOT=%@", objRoot],
                                                                             [NSString stringWithFormat:@"SYMROOT=%@", symRoot],
                                                                             [NSString stringWithFormat:@"SHARED_PRECOMPS_DIR=%@", sharedPrecompsDir],
                                                                             @"-showBuildSettings",
                                                                             ]]];

  [settingsTask setEnvironment:@{
                                 @"DYLD_INSERT_LIBRARIES" : [XCToolLibPath() stringByAppendingPathComponent:@"xcodebuild-fastsettings-shim.dylib"],
                                 @"SHOW_ONLY_BUILD_SETTINGS_FOR_TARGET" : testableTarget,
                                 }];

  NSDictionary *result = LaunchTaskAndCaptureOutput(settingsTask);
  [settingsTask release];
  settingsTask = nil;

  NSDictionary *allSettings = BuildSettingsFromOutput(result[@"stdout"]);
  NSAssert([allSettings count] == 1,
           @"Should only have build settings for a single target.");

  NSDictionary *testableBuildSettings = allSettings[testableTarget];
  NSAssert(testableBuildSettings != nil,
           @"Should have found build settings for target '%@'",
           testableTarget);

  NSArray *arguments = testable[@"arguments"];
  NSDictionary *environment = testable[@"environment"];

  // In Xcode, you can optionally include variables in your args or environment
  // variables.  i.e. "$(ARCHS)" gets transformed into "armv7".
  if ([testable[@"macroExpansionProjectPath"] isNotEqualTo:[NSNull null]]) {
    arguments = [self argumentsWithMacrosExpanded:arguments
                                fromBuildSettings:testableBuildSettings];
    environment = [self enviornmentWithMacrosExpanded:environment
                                    fromBuildSettings:testableBuildSettings];
  }

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

  // Set up blocks.
  NSMutableArray *executions = [[[NSMutableArray alloc] init] autorelease];
  
  for (NSArray *testConfiguration in testConfigurations) {
    NSArray *reportersForConfiguration = (self.parallelize
                                          ? [BufferedReporter wrapReporters:rawReporters]
                                          : rawReporters);
    Class testRunnerClass = testConfiguration[0];
    BOOL garbageCollectionEnabled = [testConfiguration[1] boolValue];

    OCUnitTestRunner *testRunner = [[[testRunnerClass alloc]
                                     initWithBuildSettings:testableBuildSettings
                                     senTestList:senTestList
                                     senTestInvertScope:senTestInvertScope
                                     arguments:arguments
                                     environment:environment
                                     garbageCollection:garbageCollectionEnabled
                                     freshSimulator:self.freshSimulator
                                     freshInstall:self.freshInstall
                                     simulatorType:self.simulatorType
                                     standardOutput:nil
                                     standardError:nil
                                     reporters:reportersForConfiguration] autorelease];

    NSDictionary *commonEventInfo = @{kReporter_BeginOCUnit_BundleNameKey: testableBuildSettings[@"FULL_PRODUCT_NAME"],
                                      kReporter_BeginOCUnit_SDKNameKey: testableBuildSettings[@"SDK_NAME"],
                                      kReporter_BeginOCUnit_TestTypeKey: isApplicationTest ? @"application-test" : @"logic-test",
                                      kReporter_BeginOCUnit_GCEnabledKey: @(garbageCollectionEnabled),
                                      };

    NSMutableDictionary *beginEvent =
    [NSMutableDictionary dictionaryWithDictionary:@{@"event": kReporter_Events_BeginOCUnit}];
    [beginEvent addEntriesFromDictionary:commonEventInfo];
    PublishEventToReporters(reportersForConfiguration, beginEvent);

    // Query list of test classes if parallelizing test classes in each target
    NSArray *testClassNames = nil;
    if (_parallelizeChunkSize > 0 && !isApplicationTest) {
      testClassNames = [testRunner testClassNames];
      if (!testClassNames) {
        ReportStatusMessage(reportersForConfiguration, REPORTER_MESSAGE_WARNING,
                            @"Failed to get test class names, not parallelizing tests in %@",
                            testableTarget);
      }
    }

    NSObject *lock = [[[NSObject alloc] init] autorelease];
    __block BOOL succeeded = YES;
    __block NSString *error = nil;
    NSMutableArray *blocks = [NSMutableArray array];

    if (testClassNames) {
      // Chop up test classes into small work units to be run in parallel.
      NSArray *workUnits = chunkifyArray(testClassNames, _parallelizeChunkSize);

      // Run the classes.
      for (NSArray *workUnit in workUnits) {
        void(^block)() = ^{
          // Since work units within a configuration are also run in parallel,
          // the reporters must be buffered again.
          NSArray *bufferedReporters = [BufferedReporter wrapReporters:reportersForConfiguration];

          OCUnitTestRunner *localTestRunner =
          [[[testRunnerClass alloc]
            initWithBuildSettings:testableBuildSettings
            senTestList:[workUnit componentsJoinedByString:@","]
            senTestInvertScope:NO
            arguments:arguments
            environment:environment
            garbageCollection:garbageCollectionEnabled
            freshSimulator:self.freshSimulator
            freshInstall:self.freshInstall
            simulatorType:self.simulatorType
            standardOutput:nil
            standardError:nil
            reporters:bufferedReporters] autorelease];

          NSString *localError = nil;
          BOOL localSucceeded = [localTestRunner runTestsWithError:&localError];

          @synchronized(lock) {
            if (!localSucceeded) {
              succeeded = NO;
            }
            error = localError;
          }
          [bufferedReporters makeObjectsPerformSelector:@selector(flush)];
        };
        [blocks addObject:[[block copy] autorelease]];
      }
    } else {
      void(^block)() = ^{
        BOOL configurationSucceeded = [testRunner runTestsWithError:&error];
        if (!configurationSucceeded) {
          @synchronized(lock) {
            succeeded = NO;
          }
        }
      };
      [blocks addObject:[[block copy] autorelease]];
    }

    BOOL (^completionBlock)() = ^{
      NSMutableDictionary *endEvent = [NSMutableDictionary dictionaryWithDictionary:
                                       @{@"event": kReporter_Events_EndOCUnit,
                                         kReporter_EndOCUnit_SucceededKey: @(succeeded),
                                         kReporter_EndOCUnit_FailureReasonKey: (error ? error : [NSNull null]),
                                         }];
      [endEvent addEntriesFromDictionary:commonEventInfo];
      PublishEventToReporters(reportersForConfiguration, endEvent);
      for (id reporter in reportersForConfiguration) {
        if ([reporter respondsToSelector:@selector(flush)]) {
          [reporter flush];
        }
      }
      return succeeded;
    };

    [executions addObject:[[TestableExecution alloc]
                           initWithBlocks:blocks
                           completionBlock:completionBlock
                           mustRunInMainThread:isApplicationTest]];
  }

  return executions;
}

- (BOOL)runTestables:(NSArray *)testables
             options:(Options *)options
    xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  dispatch_queue_t q = dispatch_queue_create("xctool.runtests",
                                             self.parallelize ? DISPATCH_QUEUE_CONCURRENT
                                                              : DISPATCH_QUEUE_SERIAL);

  // Limits the number of outstanding operations.
  // Note that the operation must not acquire this resources in one block and
  // release in another block submitted to the same queue, as it may lead to
  // starvation since the queue may not run the release block.
  dispatch_semaphore_t jobLimiter = dispatch_semaphore_create([[NSProcessInfo processInfo] processorCount]);

  // The top-level jobs which discover and kicks off tests (or queue them to run
  // in main thread).
  dispatch_group_t testDiscoveryJobs = dispatch_group_create();
  
  // Completion blocks populated by testDiscoveryJobs. Should be waited on
  // *after* discovery jobs. The draining of this group signals completion of
  // all async executed jobs.
  dispatch_group_t testCompletionJobs = dispatch_group_create();

  NSObject *succeededLock = [[[NSObject alloc] init] autorelease];
  __block BOOL succeeded = YES;

  // List of tests that must run in main thread. These are queued up to be run
  // after all async tests complete.
  NSMutableArray *executionsToRunInMainThread = [NSMutableArray array];

  NSArray *xcodebuildArguments = [options commonXcodeBuildArgumentsForSchemeAction:@"TestAction"
                                                                  xcodeSubjectInfo:xcodeSubjectInfo];

  for (NSDictionary *testable in testables) {
    dispatch_group_async(testDiscoveryJobs, q, ^{
      dispatch_semaphore_wait(jobLimiter, DISPATCH_TIME_FOREVER);

      BOOL senTestInvertScope = [testable[@"senTestInvertScope"] boolValue];
      NSString *senTestList = testable[@"senTestList"];

      NSArray *executions =
      [self executionsForTestable:testable
                        reporters:options.reporters
                          objRoot:xcodeSubjectInfo.objRoot
                          symRoot:xcodeSubjectInfo.symRoot
                sharedPrecompsDir:xcodeSubjectInfo.sharedPrecompsDir
                   xcodeArguments:xcodebuildArguments
                      senTestList:senTestList
               senTestInvertScope:senTestInvertScope];

      for (TestableExecution *execution in executions) {
        if (execution.mustRunInMainThread) {
          [executionsToRunInMainThread addObject:execution];
        } else if (self.parallelize) {
          dispatch_group_enter(testCompletionJobs);
          [execution runAsyncInQueue:q limiter:jobLimiter onComplete:^(BOOL localSucceeded) {
            @synchronized(succeededLock) {
              succeeded &= localSucceeded;
            }
            dispatch_group_leave(testCompletionJobs);
          }];
        } else {
          // If not parallelizing, don't enqueue as reporters are not buffered.
          // Otherwise, the completion event is queued at end of queue, and
          // reporter messages would not come out in the right order.
          BOOL localSucceeded = [execution runSync];
          @synchronized(succeededLock) {  // Not technically necessary.
            succeeded &= localSucceeded;
          }
        }
      }

      dispatch_semaphore_signal(jobLimiter);
    });
  }

  dispatch_group_wait(testDiscoveryJobs, DISPATCH_TIME_FOREVER);
  dispatch_group_wait(testCompletionJobs, DISPATCH_TIME_FOREVER);

  // At this point all async tests have completed.

  for (TestableExecution *execution in executionsToRunInMainThread) {
    succeeded &= [execution runSync];
  }

  dispatch_release(testCompletionJobs);
  dispatch_release(testDiscoveryJobs);
  dispatch_release(jobLimiter);
  dispatch_release(q);

  return succeeded;
}

@end
