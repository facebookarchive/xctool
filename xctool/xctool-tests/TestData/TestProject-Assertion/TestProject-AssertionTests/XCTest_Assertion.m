//
//  TestProject_ExceptionTests.m
//  TestProject-ExceptionTests
//
//  Created by Ryan Rhee on 10/9/13.
//  Copyright (c) 2013 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface XCTest_Assertion : XCTestCase

@end

@implementation XCTest_Assertion

- (void)setUp
{
  [super setUp];
  // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
  // Put teardown code here. This method is called after the invocation of each test method in the class.
  [super tearDown];
}

- (void)testPasses
{
  XCTAssertTrue(YES, @"The compiler isn't feeling well today.");
}

- (void)testAssertionFailure
{
  NSCAssert(NO, @"This assertion failed.");
}

@end
