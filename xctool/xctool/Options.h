
#import <Foundation/Foundation.h>

#import "Action.h"

/**
 * Options is a special case of Action.  It's an action that accepts its own params
 * (defined via +[Action options]), but also is the parent of other Actions's.  The
 * params it accepts are all the common params that xcodebuild would accept.
 */
@interface Options : Action
{
  NSMutableArray *_reporterOptions;
}

+ (NSArray *)actionClasses;

@property (nonatomic, retain) NSString *workspace;
@property (nonatomic, retain) NSString *project;
@property (nonatomic, retain) NSString *scheme;
@property (nonatomic, retain) NSString *configuration;
@property (nonatomic, retain) NSString *sdk;
@property (nonatomic, retain) NSString *arch;
@property (nonatomic, retain) NSString *toolchain;
@property (nonatomic, retain) NSString *xcconfig;
@property (nonatomic, retain) NSString *jobs;
@property (nonatomic, retain) NSString *findTarget;
@property (nonatomic, retain) NSString *findTargetPath;
@property (nonatomic, retain) NSArray *findTargetExcludePaths;

@property (nonatomic, assign) BOOL showBuildSettings;

@property (nonatomic, retain) NSMutableArray *buildSettings;
@property (nonatomic, retain) NSMutableArray *reporters;

@property (nonatomic, assign) BOOL showHelp;

@property (nonatomic, retain) NSMutableArray *actions;

- (NSArray *)commonXcodeBuildArgumentsIncludingSDK:(BOOL)includingSDK;
- (NSArray *)commonXcodeBuildArguments;
- (NSArray *)xcodeBuildArgumentsForSubject;

@end
