
#import <Foundation/Foundation.h>
#import "Action.h"

@interface ImplicitAction : Action

@property (nonatomic, retain) NSString *workspace;
@property (nonatomic, retain) NSString *project;
@property (nonatomic, retain) NSString *scheme;
@property (nonatomic, retain) NSString *configuration;
@property (nonatomic, retain) NSString *sdk;
@property (nonatomic, retain) NSString *arch;
@property (nonatomic, retain) NSString *toolchain;
@property (nonatomic, retain) NSString *xcconfig;
@property (nonatomic, retain) NSString *jobs;

@property (nonatomic, retain) NSMutableArray *buildSettings;
@property (nonatomic, retain) NSMutableArray *reporters;

@property (nonatomic, assign) BOOL showHelp;

@property (nonatomic, retain) NSMutableArray *actions;
+ (NSArray *)actionClasses;

- (NSArray *)commonXcodeBuildArgumentsIncludingSDK:(BOOL)includingSDK;
- (NSArray *)commonXcodeBuildArguments;
- (NSArray *)xcodeBuildArgumentsForSubject;

@end
