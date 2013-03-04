
#import "Action.h"

@class Options;

@interface ActionUtil : NSObject

+ (BOOL)runXcodeBuildCommand:(NSString *)command withOptions:(Options *)options;

+ (BOOL)buildTestable:(NSDictionary *)testable
            reporters:(NSArray *)reporters
              objRoot:(NSString *)objRoot
              symRoot:(NSString *)symRoot
       xcodeArguments:(NSArray *)xcodeArguments
         xcodeCommand:(NSString *)xcodeCommand;

+ (BOOL)runTestable:(NSDictionary *)testable
          reproters:(NSArray *)reporters
            objRoot:(NSString *)objRoot
            symRoot:(NSString *)symRoot
     xcodeArguments:(NSArray *)xcodeArguments
            testSDK:(NSString *)testSDK
        senTestList:(NSString *)senTestList
 senTestInvertScope:(BOOL)senTestInvertScope;

+ (BOOL)buildTestables:(NSArray *)testables
               command:(NSString *)command
               options:(Options *)options
         buildTestInfo:(BuildTestInfo *)buildTestInfo;

+ (BOOL)runTestables:(NSArray *)testables
             testSDK:(NSString *)testSDK
             options:(Options *)options
       buildTestInfo:(BuildTestInfo *)buildTestInfo;

@end
