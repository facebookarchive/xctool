
#import "RunTestsAction.h"

#import <launch.h>

#import "OCUnitIOSAppTestRunner.h"
#import "OCUnitIOSLogicTestRunner.h"
#import "OCUnitOSXAppTestRunner.h"
#import "OCUnitOSXLogicTestRunner.h"
#import "Options.h"
#import "Reporter.h"
#import "TaskUtil.h"
#import "XcodeSubjectInfo.h"
#import "XCToolUtil.h"

static void GetJobsIterator(const launch_data_t launch_data, const char *key, void *context) {
  void (^block)(const launch_data_t, const char *) = context;
  block(launch_data, key);
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
    [Action actionOptionWithName:@"killSimulator"
                         aliases:nil
                     description:@"kill simulator before testing starts"
                         setFlag:@selector(setKillSimulator:)],
    ];
}

- (id)init
{
  if (self = [super init]) {
    self.onlyList = [NSMutableArray array];
  }
  return self;
}

- (void)dealloc {
  self.onlyList = nil;
  self.testSDK = nil;
  [super dealloc];
}

- (void)addOnly:(NSString *)argument
{
  [self.onlyList addObject:argument];
}

/**
 Kill any active simulator plus any other iOS services it started via launchd.
 */
- (void)killSimulatorJobs
{
  launch_data_t getJobsMessage = launch_data_new_string(LAUNCH_KEY_GETJOBS);
  launch_data_t response = launch_msg(getJobsMessage);

  assert(launch_data_get_type(response) == LAUNCH_DATA_DICTIONARY);

  launch_data_dict_iterate(response, GetJobsIterator, ^(const launch_data_t launch_data, const char *keyCString){
    NSString *key = [NSString stringWithCString:keyCString encoding:NSUTF8StringEncoding];

    NSArray *strings = @[@"com.apple.iphonesimulator",
                         @"UIKitApplication",
                         @"SimulatorBridge",
                         ];

    BOOL matches = NO;
    for (NSString *str in strings) {
      if ([key rangeOfString:str options:NSCaseInsensitiveSearch].length > 0) {
        matches = YES;
        break;
      }
    }

    if (matches) {
      launch_data_t stopMessage = launch_data_alloc(LAUNCH_DATA_DICTIONARY);
      launch_data_dict_insert(stopMessage, launch_data_new_string([key UTF8String]), LAUNCH_KEY_REMOVEJOB);
      launch_data_t stopResponse = launch_msg(stopMessage);

      launch_data_free(stopMessage);
      launch_data_free(stopResponse);
    }
  });

  launch_data_free(response);
  launch_data_free(getJobsMessage);
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

- (BOOL)validateOptions:(NSString **)errorMessage
          xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
         options:(Options *)options
{
  if (self.testSDK == nil) {
    // If specified test SDKs aren't provided, just inherit the main SDK.
    self.testSDK = options.sdk;
  }

  if (![self validateSDK:self.testSDK]) {
    *errorMessage = [NSString stringWithFormat:@"run-tests: '%@' is not a supported SDK for testing.", self.testSDK];
    return NO;
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
        newTestable[@"senTestInvertScope"] = @NO;

        if (only[@"senTestList"] != [NSNull null]) {
          newTestable[@"senTestList"] = only[@"senTestList"];
        }

        [newTestables addObject:newTestable];
      }
    }
    testables = newTestables;
  }

  if (self.killSimulator) {
    [self killSimulatorJobs];
  }

  if (![self runTestables:testables
                  testSDK:self.testSDK
                  options:options
         xcodeSubjectInfo:xcodeSubjectInfo]) {
    return NO;
  }

  return YES;
}

- (BOOL)runTestable:(NSDictionary *)testable
          reproters:(NSArray *)reporters
            objRoot:(NSString *)objRoot
            symRoot:(NSString *)symRoot
  sharedPrecompsDir:(NSString *)sharedPrecompsDir
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
                              [NSString stringWithFormat:@"SHARED_PRECOMPS_DIR=%@", sharedPrecompsDir],
                              @"-showBuildSettings",
                              ]]];
  [settingsTask setEnvironment:@{
   @"DYLD_INSERT_LIBRARIES" : [PathToXCToolBinaries() stringByAppendingPathComponent:@"xcodebuild-fastsettings-shim.dylib"],
   @"SHOW_ONLY_BUILD_SETTINGS_FOR_TARGET" : testableTarget,
   }];

  NSDictionary *result = LaunchTaskAndCaptureOutput(settingsTask);
  NSDictionary *allSettings = BuildSettingsFromOutput(result[@"stdout"]);
  assert(allSettings.count == 1);
  NSDictionary *testableBuildSettings = allSettings[testableTarget];

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
  } else {
    NSAssert(NO, @"Unexpected SDK: %@", sdkName);
  }

  BOOL succeeded = YES;

  for (NSArray *testConfiguration in testConfigurations) {
    Class testRunnerClass = testConfiguration[0];
    BOOL garbageCollectionEnabled = [testConfiguration[1] boolValue];

    OCUnitTestRunner *testRunner = [[[testRunnerClass alloc]
                                     initWithBuildSettings:testableBuildSettings
                                     senTestList:senTestList
                                     senTestInvertScope:senTestInvertScope
                                     garbageCollection:garbageCollectionEnabled
                                     standardOutput:nil
                                     standardError:nil
                                     reporters:reporters] autorelease];

    NSDictionary *commonEventInfo = @{kReporter_BeginOCUnit_BundleNameKey: testableBuildSettings[@"FULL_PRODUCT_NAME"],
                                      kReporter_BeginOCUnit_SDKNameKey: testableBuildSettings[@"SDK_NAME"],
                                      kReporter_BeginOCUnit_TestTypeKey: isApplicationTest ? @"application-test" : @"logic-test",
                                      kReporter_BeginOCUnit_GCEnabledKey: @(garbageCollectionEnabled),
                                      };

    NSMutableDictionary *beginEvent = [NSMutableDictionary dictionaryWithDictionary:@{
                                       @"event": kReporter_Events_BeginOCUnit,
                                       }];
    [beginEvent addEntriesFromDictionary:commonEventInfo];
    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:beginEvent];

    NSString *error = nil;
    BOOL configurationSucceeded = [testRunner runTestsWithError:&error];

    if (!configurationSucceeded) {
      succeeded = NO;
    }

    NSMutableDictionary *endEvent = [NSMutableDictionary dictionaryWithDictionary:@{
                                     @"event": kReporter_Events_EndOCUnit,
                                                 kReporter_EndOCUnit_SucceededKey: @(succeeded),
                                             kReporter_EndOCUnit_FailureReasonKey: (error ? error : [NSNull null]),
                                     }];
    [endEvent addEntriesFromDictionary:commonEventInfo];
    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:endEvent];
  }

  return succeeded;
}

- (BOOL)runTestables:(NSArray *)testables
             testSDK:(NSString *)testSDK
             options:(Options *)options
    xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  BOOL succeeded = YES;

  for (NSDictionary *testable in testables) {
    BOOL senTestInvertScope = [testable[@"senTestInvertScope"] boolValue];
    NSString *senTestList = testable[@"senTestList"];

    if (![self runTestable:testable
                 reproters:options.reporters
                   objRoot:xcodeSubjectInfo.objRoot
                   symRoot:xcodeSubjectInfo.symRoot
         sharedPrecompsDir:xcodeSubjectInfo.sharedPrecompsDir
            xcodeArguments:[options commonXcodeBuildArgumentsIncludingSDK:NO]
                   testSDK:testSDK
               senTestList:senTestList
        senTestInvertScope:senTestInvertScope]) {
      succeeded = NO;
    }
  }

  return succeeded;
}

- (BOOL)validateSDK:(NSString *)sdk
{
  NSMutableArray *supportedTestSDKs = [NSMutableArray array];
  for (NSString *sdk in [GetAvailableSDKsAndAliases() allKeys]) {
    if ([sdk hasPrefix:@"iphonesimulator"] || [sdk hasPrefix:@"macosx"]) {
      [supportedTestSDKs addObject:sdk];
    }
  }

  // We'll only test the iphonesimulator SDKs right now.
  return [supportedTestSDKs containsObject:sdk];
}

@end
