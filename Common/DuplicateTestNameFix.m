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

#import <objc/runtime.h>

#import <Foundation/Foundation.h>

#import "ParseTestName.h"
#import "Swizzle.h"

NSArray *TestsFromSuite(id testSuite)
{
  NSMutableArray *tests = [NSMutableArray array];
  NSMutableArray *queue = [NSMutableArray array];
  [queue addObject:testSuite];

  while ([queue count] > 0) {
    id test = [queue objectAtIndex:0];
    [queue removeObjectAtIndex:0];

    if ([test isKindOfClass:[testSuite class]] ||
        [test respondsToSelector:@selector(tests)]) {
      // Both SenTestSuite and XCTestSuite keep a list of tests in an ivar
      // called 'tests'.
      id testsInSuite = [test valueForKey:@"tests"];
      NSCAssert(testsInSuite != nil, @"Can't get tests for suite: %@", testSuite);
      [queue addObjectsFromArray:testsInSuite];
    } else {
      [tests addObject:test];
    }
  }

  return tests;
}

// Key used by objc_setAssociatedObject
static int TestDescriptionKey;

static NSString *TestCase_nameOrDescription(id self, SEL cmd)
{
  id description = objc_getAssociatedObject(self, &TestDescriptionKey);
  NSCAssert(description != nil, @"Value for `TestNameKey` wasn't set.");
  return description;
}

static NSString *TestNameWithCount(NSString *name, NSUInteger count) {
  NSString *className = nil;
  NSString *methodName = nil;
  ParseClassAndMethodFromTestName(&className, &methodName, name);

  return [NSString stringWithFormat:@"-[%@ %@_%ld]",
          className,
          methodName,
          (unsigned long)count];
}

static void ProcessTestSuite(id testSuite)
{
  NSCountedSet *seenCounts = [NSCountedSet set];
  NSMutableSet *classesToSwizzle = [NSMutableSet set];

  for (id test in TestsFromSuite(testSuite)) {
    NSString *description = [test performSelector:@selector(description)];
    [seenCounts addObject:description];

    NSUInteger seenCount = [seenCounts countForObject:description];

    NSString *newDescription = nil;

    if (seenCount > 1) {
      // It's a duplicate - we need to override the name.
      newDescription = TestNameWithCount(description, seenCount);
    } else {
      newDescription = description;
    }

    objc_setAssociatedObject(test,
                             &TestDescriptionKey,
                             newDescription,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [classesToSwizzle addObject:[test class]];
  }

  for (Class cls in classesToSwizzle) {
    // In all versions of XCTest.framework and SenTestingKit.framework I can
    // find, the `name` method generates the actual string, and `description`
    // just calls `name`.  We override both, because we don't know which things
    // call which.
    class_replaceMethod(cls, @selector(description), (IMP)TestCase_nameOrDescription, "@@:");
    class_replaceMethod(cls, @selector(name), (IMP)TestCase_nameOrDescription, "@@:");
  }
}

static id TestProbe_specifiedTestSuite(Class cls, SEL cmd)
{
  id testSuite = objc_msgSend(cls,
                              sel_registerName([[NSString stringWithFormat:@"__%s_specifiedTestSuite",
                                                 class_getName(cls)] UTF8String]));
  ProcessTestSuite(testSuite);
  return testSuite;
}

static id TestSuite_allTests(Class cls, SEL cmd)
{
  id testSuite = objc_msgSend(cls,
                              sel_registerName([[NSString stringWithFormat:@"__%s_allTests",
                                                 class_getName(cls)] UTF8String]));
  ProcessTestSuite(testSuite);
  return testSuite;
}

void ApplyDuplicateTestNameFix(NSString *testProbeClassName, NSString *testSuiteClassName)
{
  // Hooks into `[-(Sen|XC)TestProbe specifiedTestSuite]` so we have a chance
  // to 1) scan over the entire list of tests to be run, 2) rewrite any
  // duplicate names we find, and 3) return the modified list to the caller.
  XTSwizzleClassSelectorForFunction(NSClassFromString(testProbeClassName),
                                    @selector(specifiedTestSuite),
                                    (IMP)TestProbe_specifiedTestSuite);

  // Hooks into `[-(Sen|XC)TestSuite allTests]` so we have a chance
  // to 1) scan over the entire list of tests to be run, 2) rewrite any
  // duplicate names we find, and 3) return the modified list to the caller.
  XTSwizzleClassSelectorForFunction(NSClassFromString(testSuiteClassName),
                                    @selector(allTests),
                                    (IMP)TestSuite_allTests);
}
