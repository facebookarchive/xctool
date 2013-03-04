
#import <Foundation/Foundation.h>

#define kActionOptionName @"kActionOptionName"
#define kActionOptionMatcherBlock @"kActionOptionMatcherBlock"
#define kActionOptionParamName @"kActionOptionParamName"
#define kActionOptionAliases @"kActionOptionAliases"
#define kActionOptionDescription @"kActionOptionDescription"
#define kActionOptionMapToSelector @"kActionOptionMapToSelector"
#define kActionOptionSetFlagSelector @"kActionOptionSetFlagSelector"

@class BuildTestInfo;
@class ImplicitAction;
@class Options;

@interface Action : NSObject

+ (NSArray *)options;

+ (NSDictionary *)actionOptionWithName:(NSString *)name
                               aliases:(NSArray *)aliases
                           description:(NSString *)description
                             paramName:(NSString *)paramName
                                 mapTo:(SEL)mapToSEL;

+ (NSDictionary *)actionOptionWithName:(NSString *)name
                               aliases:(NSArray *)aliases
                           description:(NSString *)description
                               setFlag:(SEL)setFlagSEL;

+ (NSDictionary *)actionOptionWithMatcher:(BOOL (^)(NSString *))matcherBlock
                              description:(NSString *)description
                                paramName:(NSString *)paramName
                                    mapTo:(SEL)mapToSEL;

+ (NSString *)actionUsage;

- (NSUInteger)consumeArguments:(NSMutableArray *)arguments errorMessage:(NSString **)errorMessage;

- (BOOL)validateOptions:(NSString **)errorMessage
          buildTestInfo:(BuildTestInfo *)buildTestInfo
         implicitAction:(ImplicitAction *)implicitAction;

- (BOOL)performActionWithOptions:(Options *)options buildTestInfo:(BuildTestInfo *)buildTestInfo;

@end
