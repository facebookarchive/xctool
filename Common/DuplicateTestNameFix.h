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

/**
 This workaround will enumerate all tests in a bundle, look for test cases with
 duplicate names, and add numbered suffixes to all duplicates.  This is a
 workaround for Kiwi + Specta, where it's possible for multiple test cases to
 have the same names.

 In Kiwi, test names are generated from a combination of the 'describe' and 'it'
 labels.

 e.g., in the following test case ...

   SPEC_BEGIN(FooTests)
   describe(@"Some Description", ^{
    it(@"it something", ^{
      // a test case
    });
   });
   SPEC_END

 ..., the test will be called `-[FooTests SomeDescription_ItSomething]` when its
 output is printed.  The problem is that the 'describe' and 'it' labels don't
 have to be unique, and this breaks some core assumptions in xctool.

 The parallelization features of xctool depend on being able to uniquely
 identify each test in the bundle.  Also, xctool's test result parser blows up
 if it sees multiple results for the same test.

 More conversation on this topic:
 https://github.com/allending/Kiwi/issues/402
 */
void ApplyDuplicateTestNameFix(NSString *testProbeClassName, NSString *testSuiteClassName);

/**
 Crawls the (Sen|XC)TestSuite hierarchy and returns a list of (Sen|XC)TestCase
 objects in the order that they were found.
 */
NSArray *TestsFromSuite(id testSuite);
