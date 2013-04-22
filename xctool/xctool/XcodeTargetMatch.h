#import <Foundation/Foundation.h>

@interface XcodeTargetMatch : NSObject

@property (nonatomic, copy) NSString *workspacePath;
@property (nonatomic, copy) NSString *projectPath;
@property (nonatomic, copy) NSString *schemeName;
@property (nonatomic, assign) NSUInteger numTargetsInScheme;

@end
