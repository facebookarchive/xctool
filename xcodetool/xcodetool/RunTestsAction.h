
#import "Action.h"

@interface RunTestsAction : Action

@property (nonatomic, assign) BOOL killSimulator;
@property (nonatomic, retain) NSString *testSDK;
@property (nonatomic, retain) NSMutableArray *onlyList;

@end
