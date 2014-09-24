//
// Copyright 2013 Facebook
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <UIKit/UIKit.h>

#include <dlfcn.h>

/*
 *  If xctool used under Xcode 6 then xctool doesn't use this app at all.
 *  But when xctool is used under Xcode 5 then this iOS app is used to install
 *  other apps on iOS Simulator and so methods below will be called.
 *
 *  Stub methods are required to build the app under Xcode 6 and still be
 *  able to use the app when running xctool undex Xcode 5.
 *  
 *  Method implementations will be taken from MobileInstallation framework.
 */
typedef
int MobileInstallationUninstall(CFStringRef bundleID,
                                CFDictionaryRef installationOptions,
                                // This is a function pointer.  You can get
                                // callbacks on the progresss - I don't know
                                // the full function signature.
                                void *unknown1);
typedef
int MobileInstallationInstall(CFStringRef bundlePath,
                              CFDictionaryRef installationOptions,
                              void *unknown1,
                              void *unknown2);

int MobileInstallationUninstallStub(CFStringRef bundleID, CFDictionaryRef installationOptions, void *unknown1)
{
  MobileInstallationUninstall *sym = dlsym(RTLD_DEFAULT, "MobileInstallationUninstall");
  return sym(bundleID, installationOptions, unknown1);
}

int MobileInstallationInstallStub(CFStringRef bundlePath,
                                  CFDictionaryRef installationOptions,
                                  void *unknown1,
                                  void *unknown2)
{
  MobileInstallationInstall *sym = dlsym(RTLD_DEFAULT, "MobileInstallationInstall");
  return sym(bundlePath, installationOptions, unknown1, unknown2);
}

@interface AppDelegate : NSObject <UIApplicationDelegate>
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
  NSArray *args = [[NSProcessInfo processInfo] arguments];
  NSString *action = args[1];

  if ([action isEqualToString:@"install"]) {
    NSString *appPath = args[2];
    NSLog(@"installing '%@'...", appPath);
    int result = MobileInstallationInstallStub((CFStringRef)appPath,
                                               (CFDictionaryRef)[NSDictionary dictionary],
                                               NULL,
                                               NULL);
    NSLog(@"install finished with result: %d", result);
  } else if ([action isEqualToString:@"uninstall"]) {
    NSString *bundleID = args[2];
    NSLog(@"uninstalling '%@'...", bundleID);
    int result = MobileInstallationUninstallStub((CFStringRef)bundleID, NULL, NULL);
    NSLog(@"uninstall finished with result: %d", result);
  } else {
    NSAssert(NO, @"unexpected action: %@", action);
  }

  [[UIApplication sharedApplication] performSelector:@selector(terminateWithSuccess)
                                          withObject:nil
                                          afterDelay:0.5];
}

@end

int main(int argc, char *argv[])
{
  @autoreleasepool {
    UIApplicationMain(argc, argv, nil, @"AppDelegate");
  }
  return 0;
}
