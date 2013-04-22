
#import "TestAction.h"
#import "TestActionInternal.h"

#import "BuildTestsAction.h"
#import "RunTestsAction.h"

@interface TestAction ()

@property (nonatomic, retain) BuildTestsAction *buildTestsAction;
@property (nonatomic, retain) RunTestsAction *runTestsAction;

@end

@implementation TestAction

+ (NSString *)name
{
  return @"test";
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
    _buildTestsAction = [[BuildTestsAction alloc] init];
    _runTestsAction = [[RunTestsAction alloc] init];
  }
  return self;
}

- (void)dealloc {
  self.buildTestsAction = nil;
  self.runTestsAction = nil;
  [super dealloc];
}

- (void)setTestSDK:(NSString *)testSDK
{
  _runTestsAction.testSDK = testSDK;
}

- (void)setKillSimulator:(BOOL)killSimulator
{
  _runTestsAction.killSimulator = killSimulator;
}

- (void)addOnly:(NSString *)argument
{
  [_buildTestsAction.onlyList addObject:argument];
  [_runTestsAction.onlyList addObject:argument];
}

- (NSArray *)onlyList
{
  return _buildTestsAction.onlyList;
}

- (BOOL)validateOptions:(NSString **)errorMessage
       xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
                options:(Options *)options
{
  if (![_buildTestsAction validateOptions:errorMessage
                         xcodeSubjectInfo:xcodeSubjectInfo
                                  options:options]) {
    return NO;
  }

  if (![_runTestsAction validateOptions:errorMessage
                       xcodeSubjectInfo:xcodeSubjectInfo
                                options:options]) {
    return NO;
  }

  return YES;
}

- (BOOL)performActionWithOptions:(Options *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  if (![_buildTestsAction performActionWithOptions:options xcodeSubjectInfo:xcodeSubjectInfo]) {
    return NO;
  }

  if (![_runTestsAction performActionWithOptions:options xcodeSubjectInfo:xcodeSubjectInfo]) {
    return NO;
  }

  return YES;
}

@end
