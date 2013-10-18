//
//  TestProject64bitTests.m
//  TestProject64bitTests
//
//  Created by Ryan Rhee on 10/18/13.
//  Copyright (c) 2013 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface TestProject64bitTests : XCTestCase

@end

@implementation TestProject64bitTests

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

- (void)testExample
{
#ifdef __i386__
  NSLog(@"i386");
#else
  NSLog(@"x86_64");
#endif
    XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
}

@end
