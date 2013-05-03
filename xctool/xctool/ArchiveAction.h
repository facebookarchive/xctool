#import <Foundation/Foundation.h>

#import "Action.h"

@interface ArchiveAction : Action

+ (BOOL)runXcodeBuildCommand:(NSString *)command withOptions:(Options *)options;

@end
