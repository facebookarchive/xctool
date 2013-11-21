
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
}