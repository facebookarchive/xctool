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
 By replacing default implementation of `isEqual` and `hash` we could guarantee
 that there will be no test duplicates in test suites.

 [Based on SenTesting framework implementation of category
 NSObject (SenTestRuntimeUtilities) found in NSObject_SenTestRuntimeUtilities.m]
 Duplicates appear because SenTesting and XCTest frameworks are recursively
 retrieving methods for a particular test case class starting from class itself
 and moving to its parent class which could also be a test case with tests. For
 each method `NSInvocation` object is created with corresponding `selector`.
 If child class implements test with the name which also exists in parent
 class then [*TestSuite allTests] returns two test cases with the same name but
 the same target which is incorrect.

 As it was found in SenTesting framework in NSObject (SenTestRuntimeUtilities)
 in method `+ (NSArray *) senAllInstanceInvocations` all invocations are stored
 in `NSSet`. Before adding new object `NSSet` checks if the same object is already
 added by using `isEqual:` and `hash`. So in this category we are returning `YES`
 in `isEqual:` if selectors of both invocations are equal and `hash` based on
 string representation of invocation selector.
 */
@interface NSInvocation (Comparison)

- (BOOL)isEqual:(id)object;
- (NSUInteger)hash;

@end
