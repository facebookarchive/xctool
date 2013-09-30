
#import <Foundation/Foundation.h>

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

/**
 * Returns a launch handler block that will fake out invocations of `xcodebuild -version`
 * to return the specified Xcode version string.
 *
 * Standard output will be in the form of:
 *  Xcode 5.0.1
 *  Build version 5A2034a
 */
+ (id)handlerForXcodeBuildVersionWithVersion:(NSString *)versionString
                                        hide:(BOOL)hide;

@end
