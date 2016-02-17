//
// Copyright 2004-present Facebook. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <XCTest/XCTest.h>

#import <execinfo.h>

#import "TestProject-TVFrameworkCustomClass.h"

@interface TestProject_TVFrameworkTests : XCTestCase

@end

@implementation TestProject_TVFrameworkTests

- (void)setUp
{
  [super setUp];
}

- (void)tearDown
{
  [super tearDown];
}

- (void)testPerformanceExample
{
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        id i = [[TestProject_TVFrameworkCustomClass alloc] init];
        [i nothing];
    }];
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

- (void)testOutputMerging
{
  fprintf(stdout, "stdout-line1\n");
  fprintf(stderr, "stderr-line1\n");
  fprintf(stdout, "stdout-line2\n");
  fprintf(stdout, "stdout-line3\n");
  fprintf(stderr, "stderr-line2\n");
  fprintf(stderr, "stderr-line3\n");
  XCTAssertTrue(YES);
}

- (void)testStream
{
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
