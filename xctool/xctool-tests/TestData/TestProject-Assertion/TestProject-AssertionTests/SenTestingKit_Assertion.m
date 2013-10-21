//
//  TestProject_ExceptionTests.m
//  TestProject-ExceptionTests
//
//  Created by Ryan Rhee on 10/9/13.
//  Copyright (c) 2013 Facebook. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import <Foundation/Foundation.h>

@interface SenTestingKit_Assertion : SenTestCase

@end

@implementation SenTestingKit_Assertion

+ (void)setUp
{
  // Put setup code here. This method is called before the invocation of each test method in the class.
  [super setUp];

}

+ (void)tearDown
{
  // Put teardown code here. This method is called after the invocation of each test method in the class.
  [super tearDown];
}

- (void)testPasses
{
  STAssertTrue(YES, @"The compiler isn't feeling well today.");
}

- (void)testAssertionFailure
{
  NSCAssert(NO, @"[GOOD1] This assertion failed.");
}

- (void)testExpectedAssertionIsSilent
{
  void (^failAssertion)() = ^void() {
    NSCAssert(NO, @"[BAD1] This assertion is expected and should not be visible.");
  };
  NSLog(@"[GOOD1] Regular logging should still be visible.");
  STAssertThrows(failAssertion(), @"[BAD2] failAssertion() should have thrown an assertion.");
}

- (void)testExpectedAssertionMissingIsNotSilent
{
  void (^passAssertion)() = ^void() {
    NSCAssert(YES, @"[BAD1] Asserting YES should never throw.");
  };
  STAssertThrows(passAssertion(), @"[GOOD1] passAssertion() didn't throw an assertion as expected.");
}

@end
