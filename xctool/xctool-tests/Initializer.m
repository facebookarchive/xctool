
#import <SenTestingKit/SenTestingKit.h>

#import "XCToolUtil.h"

__attribute__((constructor)) static void Initializer()
{
  // Before each test, make sure the temp directory is cleaned up before each run.
  [[NSNotificationCenter defaultCenter] addObserverForName:SenTestCaseDidStartNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:
   ^(NSNotification *notification){
     CleanupTemporaryDirectoryForAction();
   }];

  // Our Xcode scheme adds swizzle-guard-osx.dylib to DYLD_INSERT_LIBRARIES,
  // but we really only need that in the swizzle-guard-tests target.  Since
  // Xcode doesn't give us a target-specific way to define environment
  // variables, we inject swizzle-guard-osx.dylib into all of our test targets,
  // but selectively unset DYLD_INSERT_LIBRARIES where it causes problems.
  //
  // In xctool-tests, having this extra lib injected causes problems because
  // xctool-tests spawns other processes during tests, and we don't want our
  // DYLD_INSERT_LIBRARIES setting to cascade into spawned processes.
  unsetenv("DYLD_INSERT_LIBRARIES");
}