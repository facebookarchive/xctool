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

#import <Foundation/Foundation.h>

/**
 This replaces the implementation of `-[SenTestCase invokeTest]` with our
 own implementation that creates a new autorelease pool around the invocation
 of setUp, <test method>, tearDown.

 SenTestingKit *does* wrap test executions in autorelease pools, but it does it
 like this...

   1a. pool = [[NSAutoreleasePool alloc] init]
   2a. Announce test case started with: "Test Case '...' started."
   3a. Call setUp
   4a. Call the [test method]
   5a. Call tearDown
   6a. Announce test case ended with: "Test Case '...' failed (0.000 seconds)."
   7a. [pool drain]

 We're modifying it to be ...

   1b. pool = [[NSAutoreleasePool alloc] init]
   2b. Announce test case started with: "Test Case '...' started."
>  3b. innerPool = [[NSAutoreleasePool alloc] init]
   4b. Call setUp
   5b. Call the [test method]
   6b. Call tearDown
>  7b. [innerPool drain]
   8b. Announce test case ended with: "Test Case '...' failed (0.000 seconds)."
   9b. [pool drain]

 This gives us two benefits...

 1. When an over-release bug occurs (i.e. when the autorelease pool drains and
    tries to free an already released object), the crash will appear to happen
    DURING the test rather than AFTER the test.  This is because we'll drain
    the pool before emitting the "Test Case '...' failed (0.000 seconds)."
    message.

 2. It insulates otest-shim from brokenness by letting the test run completely
    in a different autorelease pool.  The whole situation that prompted this was
    a test that mock'ed `[NSDate date]` via `[OCMockObject niceMockForClass:[NSDate class]]`.
    OCMock works by swizzling, and it will automatically undo its swizzle when
    the mock object is released.

    The problem was that otest-shim's code was getting called in step [6a] above
    (inside of our swizzle of `+[SenTestLog testCaseDidStop:]`), and our swizzle
    needed to call `[NSDate date]`.  But, since we were running in the same
    autorelease pool as the test, the OCMockObject for NSDate hadn't yet been
    released and so the swizzle was still live.

    otest-shim's code was trying to call the real NSDate, but getting the
    swizzled version instead.

    By creating an inner pool for the test code, we can make sure the mock
    object + swizzle get released.
 */
void XTApplySenTestCaseInvokeTestFix();
