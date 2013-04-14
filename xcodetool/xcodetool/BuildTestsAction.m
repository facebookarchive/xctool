
#import "BuildTestsAction.h"

#import "Options.h"
#import "PJSONKit.h"
#import "Reporter.h"
#import "TaskUtil.h"
#import "XcodeSubjectInfo.h"
#import "XcodeToolUtil.h"

@implementation BuildTestsAction

+ (NSString *)name
{
  return @"build-tests";
}

+ (NSArray *)options
{
  return @[
  [Action actionOptionWithName:@"only"
                       aliases:nil
                   description:@"build only a specific test TARGET"
                     paramName:@"TARGET"
                         mapTo:@selector(addOnly:)],
  ];
}

+ (BOOL)buildTestable:(NSDictionary *)testable
            reporters:(NSArray *)reporters
              objRoot:(NSString *)objRoot
              symRoot:(NSString *)symRoot
    sharedPrecompsDir:(NSString *)sharedPrecompsDir
       xcodeArguments:(NSArray *)xcodeArguments
         xcodeCommand:(NSString *)xcodeCommand
{
  NSString *testableProjectPath = testable[@"projectPath"];
  NSString *testableTarget = testable[@"target"];

  NSArray *taskArguments = [xcodeArguments arrayByAddingObjectsFromArray:@[
                            @"-project", testableProjectPath,
                            @"-target", testableTarget,
                            [NSString stringWithFormat:@"OBJROOT=%@", objRoot],
                            [NSString stringWithFormat:@"SYMROOT=%@", symRoot],
                            [NSString stringWithFormat:@"SHARED_PRECOMPS_DIR=%@", sharedPrecompsDir],
                            xcodeCommand,
                            ]];

  // Build the test target.
  NSTask *buildTask = TaskInstance();
  [buildTask setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"]];
  [buildTask setArguments:taskArguments];
  [buildTask setEnvironment:@{
   @"DYLD_INSERT_LIBRARIES" : [PathToFBXcodetoolBinaries() stringByAppendingPathComponent:@"xcodebuild-lib.dylib"],
   @"PATH": @"/usr/bin:/bin:/usr/sbin:/sbin",
   }];

  [reporters makeObjectsPerformSelector:@selector(handleEvent:)
                             withObject:@{
   @"event": kReporter_Events_BeginXcodebuild,
   kReporter_BeginXcodebuild_CommandKey: xcodeCommand,
   kReporter_BeginXcodebuild_TitleKey: testableTarget,
   }];

  LaunchTaskAndFeedOuputLinesToBlock(buildTask, ^(NSString *line){
    [reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:[line XT_objectFromJSONString]];
  });

  [reporters makeObjectsPerformSelector:@selector(handleEvent:)
                             withObject:@{
   @"event": kReporter_Events_EndXcodebuild,
   kReporter_EndXcodebuild_CommandKey: xcodeCommand,
   kReporter_EndXcodebuild_TitleKey: testableTarget,
   }];

  return ([buildTask terminationStatus] == 0);
}

+ (BOOL)buildTestables:(NSArray *)testables
               command:(NSString *)command
               options:(Options *)options
      xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  for (NSDictionary *testable in testables) {
    BOOL succeeded = [self buildTestable:testable
                               reporters:options.reporters
                                 objRoot:xcodeSubjectInfo.objRoot
                                 symRoot:xcodeSubjectInfo.symRoot
                       sharedPrecompsDir:xcodeSubjectInfo.sharedPrecompsDir
                          xcodeArguments:[options commonXcodeBuildArguments]
                            xcodeCommand:command];
    if (!succeeded) {
      return NO;
    }
  }
  return YES;
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
  [super dealloc];
}

- (void)addOnly:(NSString *)argument
{
  [self.onlyList addObject:argument];
}

- (BOOL)validateOptions:(NSString **)errorMessage
          xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
         options:(Options *)options
{
  for (NSString *target in self.onlyList) {
    if ([xcodeSubjectInfo testableWithTarget:target] == nil) {
      *errorMessage = [NSString stringWithFormat:@"build-tests: '%@' is not a testing target in this scheme.", target];
      return NO;
    }
  }
  
  return YES;
}

- (NSMutableArray *)buildableList:(NSArray *)buildableList matchingTargets:(NSArray *)targets
{
  NSMutableArray *result = [NSMutableArray array];
  
  for (NSDictionary *buildable in buildableList) {
    if ([targets containsObject:buildable[@"target"]]) {
      [result addObject:buildable];
    }
  }
  
  return result;
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  NSMutableSet *targetsAdded = [NSMutableSet set];
  NSMutableArray *buildableList = [NSMutableArray array];
  
  [xcodeSubjectInfo.buildablesForTest enumerateObjectsUsingBlock:^(NSDictionary *item, NSUInteger idx, BOOL *stop) {
    NSString *target = item[@"target"];
    if (![targetsAdded containsObject:target]) {
      [targetsAdded addObject:target];
      [buildableList addObject:item];
    }
  }];

  [xcodeSubjectInfo.testables enumerateObjectsUsingBlock:^(NSDictionary *item, NSUInteger idx, BOOL *stop) {
    NSString *target = item[@"target"];
    if (![targetsAdded containsObject:target]) {
      [targetsAdded addObject:target];
      [buildableList addObject:item];
    }
  }];

  if (self.onlyList.count > 0) {
    buildableList = [self buildableList:buildableList matchingTargets:self.onlyList];
  }
  
  if (![BuildTestsAction buildTestables:buildableList
                          command:@"build"
                          options:options
                    xcodeSubjectInfo:xcodeSubjectInfo]) {
    return NO;
  }
  
  return YES;
}

@end
