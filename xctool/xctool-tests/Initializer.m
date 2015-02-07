
#import <XCTest/XCTest.h>

#import "XCToolUtil.h"

//#warning TO BE FIXED

__attribute__((constructor)) static void Initializer()
{
  // Before each test, make sure the temp directory is cleaned up before each run.
  /*[[NSNotificationCenter defaultCenter] addObserverForName:XCTestCaseDidStartNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:
   ^(NSNotification *notification){
     CleanupTemporaryDirectoryForAction();
   }];
   */
}
