//
//  TestProjectApplicationTestsThatFail.m
//  TestProjectApplicationTestsThatFail
//
//  Created by Fred Potter on 11/12/12.
//  Copyright (c) 2012 Facebook, Inc. All rights reserved.
//

#import "TestProjectApplicationTestsThatFail.h"

@implementation TestProjectApplicationTestsThatFail

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

- (void)testFail
{
  STFail(@"FAIL!");
}

@end
