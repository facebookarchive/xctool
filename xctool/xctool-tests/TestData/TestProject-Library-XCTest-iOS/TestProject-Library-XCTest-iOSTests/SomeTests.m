//
//  TestProject_Library_XCTest_iOSTests.m
//  TestProject-Library-XCTest-iOSTests
//
//  Created by Ryan Rhee on 9/18/13.
//  Copyright (c) 2013 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <execinfo.h>

@interface SomeTests : XCTestCase

@end

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

- (void)testHandlingOfUnicodeStrings
{
  fprintf(stdout, "---");
  [NSThread sleepForTimeInterval:0.25];
  fprintf(stdout, "\342");
  [NSThread sleepForTimeInterval:0.25];
  fprintf(stdout, "---\n");
  [NSThread sleepForTimeInterval:0.25];
  fprintf(stdout, "");
  fprintf(stdout, "---");
  [NSThread sleepForTimeInterval:0.25];
  fprintf(stdout, "0\xe2\x80\x94");
  [NSThread sleepForTimeInterval:0.25];
  fprintf(stdout, "---\n------\n");
  fprintf(stdout, "\n\n");
  fprintf(stdout, "");
}

- (void)testPrintSDK
{
  NSLog(@"SDK: %@", [UIDevice currentDevice].systemVersion);
}

- (void)testWillPass
{
  XCTAssertTrue(YES);
}

- (void)testWillFail
{
  NSLog(@"%@", [[NSProcessInfo processInfo] environment]);
  XCTAssertEqualObjects(@"a", @"b", @"Strings aren't equal");
}

- (void)testOutputMerging {
  fprintf(stdout, "stdout-line1\n");
  fprintf(stderr, "stderr-line1\n");
  fprintf(stdout, "stdout-line2\n");
  fprintf(stdout, "stdout-line3\n");
  fprintf(stderr, "stderr-line2\n");
  fprintf(stderr, "stderr-line3\n");
  XCTAssertTrue(YES);
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

- (void)testTimeout
{
  sleep(15);
}

- (void)testCrash
{
  [NSException raise:NSInternalInconsistencyException format:@"Test exception"];
}

- (void)testExits
{
  exit(1);
}

- (void)testAborts
{
  abort();
}

@end
