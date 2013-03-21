
#import "RunTestsAction.h"
#import "XcodeSubjectInfo.h"
#import "ActionUtil.h"
#import "Options.h"
#import "Functions.h"
#import "ApplicationTestRunner.h"

@implementation RunTestsAction

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
  for (NSString *sdk in GetAvailableSDKs()) {
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

  if (![ActionUtil runTestables:testables
                        testSDK:self.testSDK
                        options:options
                  xcodeSubjectInfo:xcodeSubjectInfo]) {
    return NO;
  }
  
  return YES;
}

@end
