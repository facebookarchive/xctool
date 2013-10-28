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

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

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

    if ([test isKindOfClass:[testSuite class]]) {
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
static int TestNameKey;

static NSString *TestCase_nameOrDescription(id self, SEL cmd)
{
  id name = objc_getAssociatedObject(self, &TestNameKey);
  NSCAssert(name != nil, @"Value for `TestNameKey` wasn't set.");
  return name;
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

static id TestProbe_specifiedTestSuite(Class cls, SEL cmd)
{
  id testSuite = objc_msgSend(cls,
                              sel_registerName([[NSString stringWithFormat:@"__%s_specifiedTestSuite",
                                                 class_getName(cls)] UTF8String]));

  NSCountedSet *seenCounts = [NSCountedSet set];
  NSMutableSet *classesToSwizzle = [NSMutableSet set];

  for (id test in TestsFromSuite(testSuite)) {
    NSString *name = [test performSelector:@selector(name)];
    [seenCounts addObject:name];

    NSUInteger seenCount = [seenCounts countForObject:name];

    NSString *newName = nil;

    if (seenCount > 1) {
      // It's a duplicate - we need to override the name.
      newName = TestNameWithCount(name, seenCount);
    } else {
      newName = name;
    }

    objc_setAssociatedObject(test,
                             &TestNameKey,
                             newName,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [classesToSwizzle addObject:[test class]];
  }

  SEL selToSwizzle;

  if (NSClassFromString(@"XCTestCase") != NULL) {
    // In XCTest, 'name' is used for the test name.
    selToSwizzle = @selector(name);
  } else {
    // In SenTestingKit, 'description' is used for the test name.
    selToSwizzle = @selector(description);
  }

  for (Class cls in classesToSwizzle) {
    class_replaceMethod(cls, selToSwizzle, (IMP)TestCase_nameOrDescription, "@@:");
  }

  return testSuite;
}

void ApplyDuplicateTestNameFix(NSString *testProbeClassName)
{
  // Hooks into `[-(Sen|XC)TestProbe specifiedTestSuite]` so we have a chance
  // to 1) scan over the entire list of tests to be run, 2) rewrite any
  // duplicate names we find, and 3) return the modified list to the caller.
  XTSwizzleClassSelectorForFunction(NSClassFromString(testProbeClassName),
                                    @selector(specifiedTestSuite),
                                    (IMP)TestProbe_specifiedTestSuite);
}
