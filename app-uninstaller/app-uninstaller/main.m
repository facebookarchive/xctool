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

// From MobileInstallation.framework
int MobileInstallationUninstall(CFStringRef bundleID, CFDictionaryRef installationOptions, void *unknown1);

@interface AppDelegate : NSObject <UIApplicationDelegate>
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
  NSArray *args = [[NSProcessInfo processInfo] arguments];

  NSString *bundleID = args[1];
  NSLog(@"Uninstalling '%@' ...", bundleID);
  MobileInstallationUninstall((CFStringRef)bundleID, nil, NULL);

  [[UIApplication sharedApplication] performSelector:@selector(terminateWithSuccess) withObject:nil afterDelay:0.5];
}

@end

int main(int argc, char *argv[])
{
  @autoreleasepool {
    UIApplicationMain(argc, argv, nil, @"AppDelegate");
  }
  return 0;
}
