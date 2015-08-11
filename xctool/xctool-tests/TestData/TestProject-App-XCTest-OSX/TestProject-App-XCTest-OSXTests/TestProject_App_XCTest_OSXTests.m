//
//  TestProject_App_XCTest_OSXTests.m
//  TestProject-App-XCTest-OSXTests
//
//  Created by Ryan Rhee on 9/12/13.
//  Copyright (c) 2013 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <execinfo.h>

@interface TestProject_App_XCTest_OSXTests : XCTestCase

@end

@implementation TestProject_App_XCTest_OSXTests

- (void)testWillPass
{
  NSLog(@"%@", [[NSProcessInfo processInfo] environment]);
  XCTAssertEqual(1, 1, @"Equal!");
}

- (void)testWillFail
{
  XCTAssertEqual(1, 2, @"Not Equal!");
}

- (void)testOutput
{
  // Generate output in all the different ways we know of...
  fprintf(stdout, "stdout\n");
  fprintf(stderr, "stderr\n");
  NSLog(@"NSLog");
  // We've seen backtrace_symbols_fd follow a different output path
  void *exceptionSymbols[256];
  int numSymbols = backtrace(exceptionSymbols, 256);
  backtrace_symbols_fd(exceptionSymbols, numSymbols, STDERR_FILENO);
}

@end
