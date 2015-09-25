//
//  TestThatThrowsExceptionOnStart.m
//  TestThatThrowsExceptionOnStart
//
//  Created by Fred Potter on 11/21/13.
//
//

#import <XCTest/XCTest.h>

void DontSIGABRT(int signal)
{
  exit(0);
}

@interface TestThatThrowsExceptionOnStart : XCTestCase
@end

@implementation TestThatThrowsExceptionOnStart

+ (void)setUp
{
  // Crash on start, but only when run via otest.  We don't want to crash
  // when otest-query runs.
  if (strcmp("xctest", getprogname()) == 0) {

    // Raising an NSException would normally abort(), but let's not really go
    // that far.  It's going to be annoying if the CrashReporter dialog keeps
    // showing up.
    signal(SIGABRT, DontSIGABRT);

    [NSException raise:NSGenericException format:@"Let's crash on start!"];
  }
}

- (void)testExample
{
  XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
}

@end
