//
//  TestProject_App_OSXTests.m
//  TestProject-App-OSXTests
//
//  Created by Fred Potter on 4/13/13.
//  Copyright (c) 2013 Fred Potter. All rights reserved.
//

#import "TestProject_App_OSXTests.h"

#import <execinfo.h>

#import "Something.h"

@implementation TestProject_App_OSXTests

- (void)testWillPass
{
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

- (void)testCanUseSymbolsFromTestHost
{
  // Just reference a symbol in the TEST_HOST just to make sure we can.  If the
  // test bundle doesn't load, it will mean that we're not properly loading the
  // test bundle inside of the running TEST_HOST.
  Something *something = [[Something alloc] init];
  NSLog(@"Something: %@", something);
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
