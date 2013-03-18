
#import "Options.h"
#import "Reporter.h"
#import "PJSONKit.h"
#import "Functions.h"
#import "XcodeSubjectInfo.h"
#import "ImplicitAction.h"
#import "BuildAction.h"
#import "CleanAction.h"
#import "BuildTestsAction.h"
#import "RunTestsAction.h"

@implementation Options

+ (NSArray *)actionClasses
{
  return @[@[@"clean", [CleanAction class]],
           @[@"build", [BuildAction class]],
           @[@"build-tests", [BuildTestsAction class]],
           @[@"run-tests", [RunTestsAction class]],
           ];
}

- (id)init
{
  if (self = [super init]) {
    self.actions = [NSMutableArray array];
    self.implicitAction = [[[ImplicitAction alloc] init] autorelease];
  }
  return self;
}

- (void)dealloc
{
  self.actions = nil;
  [super dealloc];
}

- (BOOL)parseOptionsFromArgumentList:(NSArray *)arguments errorMessage:(NSString **)errorMessage;
{
  BOOL succeeded = YES;
  
  NSMutableDictionary *verbToClass = [NSMutableDictionary dictionary];
  for (NSArray *verbAndClass in [Options actionClasses]) {
    verbToClass[verbAndClass[0]] = verbAndClass[1];
  }
  
  NSMutableArray *argumentList = [NSMutableArray arrayWithArray:arguments];
  while (argumentList.count > 0) {
    [self.implicitAction consumeArguments:argumentList errorMessage:errorMessage];
    
    if (argumentList.count == 0) {
      break;
    }
    
    NSString *argument = argumentList[0];
    [argumentList removeObjectAtIndex:0];
    
    if (verbToClass[argument]) {
      Action *action = [[[verbToClass[argument] alloc] init] autorelease];
      [action consumeArguments:argumentList errorMessage:errorMessage];
      [self.actions addObject:action];
    } else {
      *errorMessage = [NSString stringWithFormat:@"Unexpected action: %@", argument];
      succeeded = NO;
      break;
    }
  }
  
  return succeeded;
}

- (BOOL)validateOptions:(NSString **)errorMessage xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  if (![self.implicitAction validateOptions:errorMessage xcodeSubjectInfo:xcodeSubjectInfo implicitAction:nil]) {
    return NO;
  }
  
  for (Action *action in self.actions) {
    BOOL valid = [action validateOptions:errorMessage xcodeSubjectInfo:xcodeSubjectInfo implicitAction:self.implicitAction];
    if (!valid) {
      return NO;
    }
  }
  
  // Assume build if no action is given.
  if (self.actions.count == 0) {
    [self.actions addObject:[[[BuildAction alloc] init] autorelease]];
  }
  
  return YES;
}

@end
