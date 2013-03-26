
#import "RunTestsAction.h"
#import "XcodeSubjectInfo.h"
#import "Options.h"
#import "XcodeToolUtil.h"
#import "ApplicationTestRunner.h"
#import "LogicTestRunner.h"
#import "XcodeSubjectInfo.h"
#import "TaskUtil.h"

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
    if ([sdk hasPrefix:@"iphonesimulator"]) {
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
    [ApplicationTestRunner removeAllSimulatorJobs];
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

  assert([testableBuildSettings[@"SDK_NAME"] hasPrefix:@"iphonesimulator"]);

  Class testRunnerClass = {0};

  if (testableBuildSettings[@"TEST_HOST"] != nil) {
    testRunnerClass = [ApplicationTestRunner class];
  } else {
    testRunnerClass = [LogicTestRunner class];
  }

  TestRunner *testRunner = [[[testRunnerClass alloc]
                             initWithBuildSettings:testableBuildSettings
                             senTestList:senTestList
                             senTestInvertScope:senTestInvertScope
                             standardOutput:nil
                             standardError:nil
                             reporters:reporters] autorelease];

  [reporters makeObjectsPerformSelector:@selector(handleEvent:)
                              withObject:@{
   @"event": @"begin-octest",
   @"title": testableBuildSettings[@"FULL_PRODUCT_NAME"],
   @"titleExtra": testableBuildSettings[@"SDK_NAME"],
   }];

  NSString *error = nil;
  BOOL succeeded = [testRunner runTestsWithError:&error];

  [reporters makeObjectsPerformSelector:@selector(handleEvent:)
                              withObject:@{
   @"event": @"end-octest",
   @"title": testableBuildSettings[@"FULL_PRODUCT_NAME"],
   @"titleExtra": testableBuildSettings[@"SDK_NAME"],
   @"succeeded" : @(succeeded),
   @"failureReason" : (error ? error : [NSNull null]),
   }];

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
