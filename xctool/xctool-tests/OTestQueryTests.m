//
// Copyright 2013 Facebook
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

#import <SenTestingKit/SenTestingKit.h>

#import "OTestQuery.h"
#import "XCToolUtil.h"

@interface OTestQueryTests : SenTestCase
@end

@implementation OTestQueryTests

- (void)testCanQueryClassesFromOSXBundle
{
  NSArray *classes = OTestQueryTestCasesInOSXBundle(TEST_DATA @"otest-query-tests-osx-test-bundle/TestProject-Library-OSXTests.octest",
                                                      AbsolutePathFromRelative(TEST_DATA @"otest-query-tests-osx-test-bundle"),
                                                      YES);
  assertThat(classes,
             equalTo(@[
                     @"TestProject_Library_OSXTests/testOutput",
                     @"TestProject_Library_OSXTests/testWillFail",
                     @"TestProject_Library_OSXTests/testWillPass",
                     ]));
}

- (void)testCanQueryClassesFromIOSBundle
{
  NSString *latestSDK = GetAvailableSDKsAndAliases()[@"iphonesimulator"];
  NSArray *classes = OTestQueryTestCasesInIOSBundle(TEST_DATA @"otest-query-tests-ios-test-bundle/TestProject-LibraryTests.octest",
                                                      latestSDK);
  assertThat(classes,
             equalTo(@[
                     @"OtherTests/testSomething",
                     @"SomeTests/testBacktraceOutputIsCaptured",
                     @"SomeTests/testOutputMerging",
                     @"SomeTests/testPrintSDK",
                     @"SomeTests/testStream",
                     @"SomeTests/testWillFail",
                     @"SomeTests/testWillPass",
                     ]));
}

@end
