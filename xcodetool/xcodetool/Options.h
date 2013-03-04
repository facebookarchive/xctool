
#import <Foundation/Foundation.h>

#define kActionClean @"clean"
#define kActionBuild @"build"
#define kActionBuildTests @"build-tests"
#define kActionRunTests @"run-tests"
#define kActionBuildTest @"build-test"
#define kActionRunTest @"run-test"
#define kActionBuildAndRunTest @"build-and-run-test"

@class BuildTestInfo;
@class ImplicitAction;

@interface Options : NSObject
{
}

@property (nonatomic, retain) NSMutableArray *actions;
@property (nonatomic, retain) ImplicitAction *implicitAction;

+ (NSArray *)actionClasses;

- (BOOL)parseOptionsFromArgumentList:(NSArray *)arguments errorMessage:(NSString **)errorMessage;
- (BOOL)validateOptions:(NSString **)errorMessage buildTestInfo:(BuildTestInfo *)buildTestInfo;

@end
