
#import "BuildTestsAction.h"
#import "BuildTestInfo.h"
#import "Options.h"
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
          buildTestInfo:(BuildTestInfo *)buildTestInfo
         implicitAction:(ImplicitAction *)implicitAction
{
  [buildTestInfo collectInfoIfNeededWithOptions:implicitAction];
  
  for (NSString *target in self.onlyList) {
    if ([buildTestInfo testableWithTarget:target] == nil) {
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

- (BOOL)performActionWithOptions:(Options *)options buildTestInfo:(BuildTestInfo *)buildTestInfo
{
  [buildTestInfo collectInfoIfNeededWithOptions:options.implicitAction];
  
  NSMutableSet *targetsAdded = [NSMutableSet set];
  NSMutableArray *buildableList = [NSMutableArray array];
  
  [buildTestInfo.buildablesForTest enumerateObjectsUsingBlock:^(NSDictionary *item, NSUInteger idx, BOOL *stop) {
    if (![targetsAdded containsObject:item[@"target"]]) {
      [targetsAdded addObject:@YES];
      [buildableList addObject:item];
    }
  }];

  [buildTestInfo.testables enumerateObjectsUsingBlock:^(NSDictionary *item, NSUInteger idx, BOOL *stop) {
    if (![targetsAdded containsObject:item[@"target"]]) {
      [targetsAdded addObject:@YES];
      [buildableList addObject:item];
    }
  }];
  
  if (self.onlyList.count > 0) {
    buildableList = [self buildableList:buildableList matchingTargets:self.onlyList];
  }
  
  if (![ActionUtil buildTestables:buildableList
                          command:@"build"
                          options:options
                    buildTestInfo:buildTestInfo]) {
    return NO;
  }
  
  return YES;
}

@end
