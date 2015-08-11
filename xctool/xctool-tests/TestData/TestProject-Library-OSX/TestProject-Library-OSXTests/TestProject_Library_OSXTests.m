//
//  TestProject_Library_OSXTests.m
//  TestProject-Library-OSXTests
//
//  Created by Fred Potter on 4/10/13.
//  Copyright (c) 2013 Fred Potter. All rights reserved.
//

#import "TestProject_Library_OSXTests.h"

#import <execinfo.h>

@implementation TestProject_Library_OSXTests

- (void)testWillPass
{
  XCTAssertEqualObjects(@"1", @"1", @"Equal!");
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

- (void)testStandardDirectories
{
  NSLog(@"\n"\
        "============================================================\n" \
        "   NSHomeDirectory:\n     %@\n" \
        "   NSTemporaryDirectory:\n     %@\n" \
        "   Documents:\n     %@\n" \
        "============================================================\n",
        NSHomeDirectory(),
        NSTemporaryDirectory(),
        [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]);
}

@end
