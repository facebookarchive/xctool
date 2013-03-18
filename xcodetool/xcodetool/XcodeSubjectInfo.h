
#import <Foundation/Foundation.h>

/**
 * XcodeSubjectInfo offers up info about the subject (either a workspace/scheme pair, or
 * project/scheme pair) being built or tested.
 */
@interface XcodeSubjectInfo : NSObject
{
  BOOL _didPopulate;
}

@property (nonatomic, retain) NSString *subjectWorkspace;
@property (nonatomic, retain) NSString *subjectProject;
@property (nonatomic, retain) NSString *subjectScheme;
@property (nonatomic, retain) NSArray *subjectXcodeBuildArguments;

@property (nonatomic, retain) NSString *sdkName;
@property (nonatomic, retain) NSString *objRoot;
@property (nonatomic, retain) NSString *symRoot;
@property (nonatomic, retain) NSString *configuration;
@property (nonatomic, retain) NSArray *testables;
@property (nonatomic, retain) NSArray *buildablesForTest;

/**
 * Returns a list of paths to .xcodeproj directories in the workspace.
 */
+ (NSArray *)projectPathsInWorkspace:(NSString *)workspace;

/**
 * Returns a list of paths to .xcscheme files contained within the workspace itself and for
 * all projects in the workspace.
 */
+ (NSArray *)schemePathsInWorkspace:(NSString *)workspace;

/**
 * Returns a list of paths to .xcscheme files.  Container may be an xcodeproj or xcworkspace
 * directory since either may contain xcscheme files.
 */
+ (NSArray *)schemePathsInContainer:(NSString *)project;

- (NSDictionary *)testableWithTarget:(NSString *)target;

@end
