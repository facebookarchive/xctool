
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
