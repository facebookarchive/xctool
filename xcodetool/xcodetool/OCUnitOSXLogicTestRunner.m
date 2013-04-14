// Copyright 2004-present Facebook. All Rights Reserved.


#import "OCUnitOSXLogicTestRunner.h"

#import "PJSONKit.h"
#import "TaskUtil.h"
#import "XcodeToolUtil.h"

@implementation OCUnitOSXLogicTestRunner

- (NSTask *)otestTaskWithTestBundle:(NSString *)testBundlePath
{
  NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:
                              [[NSProcessInfo processInfo] environment]];
  [env addEntriesFromDictionary:@{
   @"DYLD_INSERT_LIBRARIES" : [PathToFBXcodetoolBinaries() stringByAppendingPathComponent:@"otest-lib-osx.dylib"],
   @"DYLD_FRAMEWORK_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
   @"DYLD_LIBRARY_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
   @"DYLD_FALLBACK_FRAMEWORK_PATH" : [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/Frameworks"],
   @"NSUnbufferedIO" : @"YES",
   @"OBJC_DISABLE_GC" : !_garbageCollection ? @"YES" : @"NO",
   }];

  NSTask *task = TaskInstance();
  [task setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Tools/otest"]];
  // When invoking otest directly, the last arg needs to be the the test bundle.
  [task setArguments:[[self otestArguments] arrayByAddingObject:testBundlePath]];
  [task setEnvironment:env];

  return task;
}

- (BOOL)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock error:(NSString **)error
{
  NSAssert([_buildSettings[@"SDK_NAME"] hasPrefix:@"macosx"], @"Should be a macosx SDK.");

  NSString *testBundlePath = [self testBundlePath];
  BOOL bundleExists = [[NSFileManager defaultManager] fileExistsAtPath:testBundlePath];

  if ([[[NSProcessInfo processInfo] processName] isEqualToString:@"otest"]) {
    // If we're running under test, pretend the bundle exists even if it doesn't.
    bundleExists = YES;
  }

  if (bundleExists) {
    NSTask *task = [self otestTaskWithTestBundle:testBundlePath];

    LaunchTaskAndFeedOuputLinesToBlock(task, outputLineBlock);

    return [task terminationStatus] == 0 ? YES : NO;
  } else {
    *error = [NSString stringWithFormat:@"Test bundle not found at: %@", testBundlePath];
    return NO;
  }
}

@end
