
#import "Action.h"

@interface BuildTestsAction : Action

@property (nonatomic, retain) NSMutableArray *onlyList;

+ (BOOL)buildTestable:(NSDictionary *)testable
            reporters:(NSArray *)reporters
              objRoot:(NSString *)objRoot
              symRoot:(NSString *)symRoot
       xcodeArguments:(NSArray *)xcodeArguments
         xcodeCommand:(NSString *)xcodeCommand;

+ (BOOL)buildTestables:(NSArray *)testables
               command:(NSString *)command
               options:(Options *)options
      xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo;

@end
