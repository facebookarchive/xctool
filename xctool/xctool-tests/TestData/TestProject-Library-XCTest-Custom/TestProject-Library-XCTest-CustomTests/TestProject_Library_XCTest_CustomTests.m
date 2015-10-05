//
//  TestProject_Library_XCTest_CustomTests.m
//  TestProject-Library-XCTest-CustomTests
//
//  Created by Justin Spahr-Summers on 2015-10-01.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface TestProject_Library_XCTest_CustomTests : XCTestCase

@end

@implementation TestProject_Library_XCTest_CustomTests

+ (NSArray *)testInvocations
{
  SEL customTestSelector = @selector(customTest);
  NSMethodSignature *customTestSignature = [self instanceMethodSignatureForSelector:customTestSelector];
  NSInvocation *customTestInvocation = [NSInvocation invocationWithMethodSignature:customTestSignature];
  customTestInvocation.selector = customTestSelector;

  SEL testWithArgumentSelector = @selector(customTestWithInteger:);
  NSMethodSignature *testWithArgumentSignature = [self instanceMethodSignatureForSelector:testWithArgumentSelector];
  NSInvocation *testWithArgumentInvocation = [NSInvocation invocationWithMethodSignature:testWithArgumentSignature];
  testWithArgumentInvocation.selector = testWithArgumentSelector;

  int value = 5;
  [testWithArgumentInvocation setArgument:&value atIndex:2];

  return @[
    customTestInvocation,
    testWithArgumentInvocation,
  ];
}

- (void)customTest
{
}

- (void)customTestWithInteger:(int)value
{
  XCTAssertEqual(value, 5);
}

@end
