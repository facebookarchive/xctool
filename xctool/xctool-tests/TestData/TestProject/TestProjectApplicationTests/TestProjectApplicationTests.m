//
//  TestProjectTests.m
//  TestProjectTests
//
//  Created by Fred Potter on 11/12/12.
//  Copyright (c) 2012 Facebook, Inc. All rights reserved.
//

#import "TestProjectApplicationTests.h"

@implementation TestProjectTests

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

- (void)testSomething
{
  NSLog(@"testSomething");
  STAssertEquals(1, 1, @"1 == 1");
}

- (void)testSomethingElse
{
  NSLog(@"testSomethingElse");
  STAssertEquals(2, 2, @"2 == 2");
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
