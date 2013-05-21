
#import "TestsWithArgAndEnvSettingsTests.h"

@implementation TestsWithArgAndEnvSettingsTests

- (void)testPrintArgs
{
  printf("%s\n", [[[[NSProcessInfo processInfo] arguments] description] UTF8String]);
}

- (void)testPrintEnv
{
  printf("%s\n", [[[[NSProcessInfo processInfo] environment] description] UTF8String]);
}

@end
