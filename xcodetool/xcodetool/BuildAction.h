
#import <Foundation/Foundation.h>
#import "Action.h"

@interface BuildAction : Action

+ (BOOL)runXcodeBuildCommand:(NSString *)command withOptions:(Options *)options;

@end
