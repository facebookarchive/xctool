
#import "BuildTestsAction.h"
#import "XcodeSubjectInfo.h"
#import "ActionUtil.h"


@implementation BuildTestsAction

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
         implicitAction:(ImplicitAction *)implicitAction
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

- (BOOL)performActionWithOptions:(ImplicitAction *)options xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
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
  
  if (![ActionUtil buildTestables:buildableList
                          command:@"build"
                          options:options
                    xcodeSubjectInfo:xcodeSubjectInfo]) {
    return NO;
  }
  
  return YES;
}

@end
