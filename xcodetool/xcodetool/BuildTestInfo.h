
#import <Foundation/Foundation.h>

@class ImplicitAction;

@interface BuildTestInfo : NSObject
{
  BOOL _didCollect;
}

@property (nonatomic, retain) NSString *sdkName;
@property (nonatomic, retain) NSString *objRoot;
@property (nonatomic, retain) NSString *symRoot;
@property (nonatomic, retain) NSString *configuration;
@property (nonatomic, retain) NSArray *testables;
@property (nonatomic, retain) NSArray *buildablesForTest;

- (void)collectInfoIfNeededWithOptions:(ImplicitAction *)action;
- (NSDictionary *)testableWithTarget:(NSString *)target;

@end
