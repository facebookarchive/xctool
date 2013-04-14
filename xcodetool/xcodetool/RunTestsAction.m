
#import "RunTestsAction.h"

#import <launch.h>

#import "ApplicationTestRunner.h"
#import "OCUnitIOSLogicTestRunner.h"
#import "OCUnitOSXLogicTestRunner.h"
#import "Options.h"
#import "Reporter.h"
#import "TaskUtil.h"
#import "XcodeSubjectInfo.h"
#import "XcodeToolUtil.h"

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
  
  NSMutableArray *supportedTestSDKs = [NSMutableArray array];
  for (NSString *sdk in [GetAvailableSDKsAndAliases() allKeys]) {
    if ([sdk hasPrefix:@"iphonesimulator"] || [sdk hasPrefix:@"macosx"]) {
      [supportedTestSDKs addObject:sdk];
    }
  }
  
  // We'll only test the iphonesimulator SDKs right now.
  if (![supportedTestSDKs containsObject:self.testSDK]) {
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
    // Use whatever we found in the scheme.
    testables = xcodeSubjectInfo.testables;
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
   @"DYLD_INSERT_LIBRARIES" : [PathToFBXcodetoolBinaries() stringByAppendingPathComponent:@"xcodebuild-fastsettings-lib.dylib"],
   @"SHOW_ONLY_BUILD_SETTINGS_FOR_TARGET" : testableTarget,
   }];

  NSDictionary *result = LaunchTaskAndCaptureOutput(settingsTask);
  NSDictionary *allSettings = BuildSettingsFromOutput(result[@"stdout"]);
  assert(allSettings.count == 1);
  NSDictionary *testableBuildSettings = allSettings[testableTarget];

  NSString *sdkName = testableBuildSettings[@"SDK_NAME"];
  BOOL hasTestHost = testableBuildSettings[@"TEST_HOST"] != nil;

  Class testRunnerClass = {0};
  NSString *testType = nil;

  if (hasTestHost) {
    testType = @"application-test";
    testRunnerClass = [ApplicationTestRunner class];
  } else {
    testType = @"logic-test";

    if ([sdkName hasPrefix:@"iphonesimulator"]) {
      testRunnerClass = [OCUnitIOSLogicTestRunner class];
    } else if ([sdkName hasPrefix:@"macosx"]) {
      testRunnerClass = [OCUnitOSXLogicTestRunner class];
    } else {
      NSAssert(NO, @"Unexpected SDK: @", sdkName);
    }
  }

  OCUnitTestRunner *testRunner = [[[testRunnerClass alloc]
                             initWithBuildSettings:testableBuildSettings
                             senTestList:senTestList
                             senTestInvertScope:senTestInvertScope
                             standardOutput:nil
                             standardError:nil
                             reporters:reporters] autorelease];

  NSDictionary *commonEventInfo = @{kReporter_BeginOCUnit_BundleNameKey: testableBuildSettings[@"FULL_PRODUCT_NAME"],
                                    kReporter_BeginOCUnit_SDKNameKey: testableBuildSettings[@"SDK_NAME"],
                                    kReporter_BeginOCUnit_TestTypeKey: testType,
                                    };

  NSMutableDictionary *beginEvent = [NSMutableDictionary dictionaryWithDictionary:@{
                                     @"event": kReporter_Events_BeginOCUnit,
                                     }];
  [beginEvent addEntriesFromDictionary:commonEventInfo];
  [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:beginEvent];

  NSString *error = nil;
  BOOL succeeded = [testRunner runTestsWithError:&error];

  NSMutableDictionary *endEvent = [NSMutableDictionary dictionaryWithDictionary:@{
                                   @"event": kReporter_Events_EndOCUnit,
                                   kReporter_EndOCUnit_SucceededKey: @(succeeded),
                                   kReporter_EndOCUnit_FailureReasonKey: (error ? error : [NSNull null]),
                                   }];
  [endEvent addEntriesFromDictionary:commonEventInfo];
  [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:endEvent];

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

@end
