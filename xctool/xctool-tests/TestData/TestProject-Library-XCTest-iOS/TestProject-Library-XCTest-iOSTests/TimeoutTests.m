//
//  TimoutTests.m
//  TestProject-Library-XCTest-iOS
//
//  Created by Ryan Rheeeee on 9/18/13.
//  Copyright (c) 2013 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface TimeoutTests : XCTestCase

@end

@implementation TimeoutTests

- (void)testTimeout
{
  sleep(15);
}

@end

@interface SetupTimeoutTests : XCTestCase

@end

@implementation SetupTimeoutTests

+ (void)setUp {
  [super setUp];
  sleep(15);
}

- (void)testNothing
{
  XCTAssertTrue(YES);
}

@end


@interface TeardownTimeoutTests : XCTestCase

@end

@implementation TeardownTimeoutTests

+ (void)tearDown {
  sleep(15);
  [super tearDown];
}

- (void)testNothing
{
  XCTAssertTrue(YES);
}


@end
