//
//  Copyright © 2018 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>

/**
 * Expected xctool output:
 *   RUN-TESTS FAILED: 2 passed, 1 failed, 1 errored, 4 total
 */

@interface TestProject_UITestsUITests : XCTestCase
@end

@implementation TestProject_UITestsUITests

- (void)setUp {
    [super setUp];
    
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // In UI tests it is usually best to stop immediately when a failure occurs.
    self.continueAfterFailure = NO;
    // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
    [[[XCUIApplication alloc] init] launch];
    
    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    NSLog(@"testExample");
    XCTAssert(true, @"Test doesn't fail");
}

- (void)testPrintArgs {
    NSLog(@"testPrintArgs: environment: %@", NSProcessInfo.processInfo.environment);
    NSLog(@"testPrintArgs: arguments: %@", NSProcessInfo.processInfo.arguments);
}

- (void)testFailure {
    XCTAssert(false, @"Fail test");
}

- (void)testException {
    printf("Test will intentionally abort()!\n");
    abort();
}

@end
