//
//  TestProject_LibraryTests.m
//  TestProject-LibraryTests
//
//  Created by Fred Potter on 1/23/13.
//
//

#import "SomeTests.h"
#import <UIKit/UIKit.h>
#include <execinfo.h>

@implementation SomeTests

- (void)setUp
{
    [super setUp];

    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.

    [super tearDown];
}

- (void)testPrintSDK
{
  NSLog(@"SDK: %@", [UIDevice currentDevice].systemVersion);
}

- (void)testWillPass
{
  STAssertTrue(YES, nil);
}

- (void)testWillFail
{
  STAssertEqualObjects(@"a", @"b", @"Strings aren't equal");
}

- (void)testOutputMerging {
  fprintf(stdout, "stdout-line1\n");
  fprintf(stderr, "stderr-line1\n");
  fprintf(stdout, "stdout-line2\n");
  fprintf(stdout, "stdout-line3\n");
  fprintf(stderr, "stderr-line2\n");
  fprintf(stderr, "stderr-line3\n");
  STAssertTrue(YES, nil);
}

- (void)testStream {
  for (int i = 0; i < 3; i++) {
    NSLog(@">>>> i = %d", i);
    [NSThread sleepForTimeInterval:0.25];
  }
}

- (void)testBacktraceOutputIsCaptured
{
  void *exceptionSymbols[256];
  int numSymbols = backtrace(exceptionSymbols, 256);
  backtrace_symbols_fd(exceptionSymbols, numSymbols, STDERR_FILENO);
}

@end
