
#import <Foundation/Foundation.h>

/**
 * Returns YES if task appears to specify an otest process, either for OS X
 * or the simulator.
 */
BOOL IsOtestTask(NSTask *task);

@interface LaunchHandlers : NSObject

/**
 * Returns a launch handler block that will fake out the -showBuildSettings
 * call for this project/scheme.
 */
+ (id)handlerForShowBuildSettingsWithProject:(NSString *)project
                                      scheme:(NSString *)scheme
                                settingsPath:(NSString *)settingsPath;

+ (id)handlerForShowBuildSettingsWithProject:(NSString *)project
                                      scheme:(NSString *)scheme
                                settingsPath:(NSString *)settingsPath
                                        hide:(BOOL)hide;

+ (id)handlerForShowBuildSettingsWithAction:(NSString *)action
                                    project:(NSString *)project
                                     scheme:(NSString *)scheme
                               settingsPath:(NSString *)settingsPath
                                       hide:(BOOL)hide;

+ (id)handlerForShowBuildSettingsWithProject:(NSString *)project
                                      target:(NSString *)target
                                settingsPath:(NSString *)settingsPath
                                        hide:(BOOL)hide;

+ (id)handlerForShowBuildSettingsErrorWithProject:(NSString *)project
                                           target:(NSString *)target
                                 errorMessagePath:(NSString *)errorMessagePath
                                             hide:(BOOL)hide;


/**
 * Returns a launch handler block that will fake out the -showBuildSettings
 * call for this workspace/scheme.
 */
+ (id)handlerForShowBuildSettingsWithWorkspace:(NSString *)workspace
                                        scheme:(NSString *)scheme
                                  settingsPath:(NSString *)settingsPath;

+ (id)handlerForShowBuildSettingsWithWorkspace:(NSString *)workspace
                                        scheme:(NSString *)scheme
                                  settingsPath:(NSString *)settingsPath
                                          hide:(BOOL)hide;

+ (id)handlerForOtestQueryReturningTestList:(NSArray *)testList;
+ (id)handlerForOtestQueryWithTestHost:(NSString *)testHost
                     returningTestList:(NSArray *)testList;

@end
