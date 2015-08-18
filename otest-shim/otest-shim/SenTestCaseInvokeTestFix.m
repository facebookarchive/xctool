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

#import "SenTestClassEnumeratorFix.h"
#import "Swizzle.h"
#import "dyld-interposing.h"

@interface XTSenTestCase : NSObject
- (NSUInteger)numberOfTestIterationsForTestWithSelector:(SEL)arg1;
- (void)afterTestIteration:(unsigned long long)arg1 selector:(SEL)arg2;
- (void)beforeTestIteration:(unsigned long long)arg1 selector:(SEL)arg2;
- (void)tearDownTestWithSelector:(SEL)arg1;
- (void)setUpTestWithSelector:(SEL)arg1;
- (void)setUp;
- (void)tearDown;
@end

static void SenTestCase_invokeTest(XTSenTestCase *self, SEL cmd)
{
  NSInvocation *invocation = [self valueForKey:@"invocation"];

  SEL selector = [invocation selector];

  // Make a new pool around our invocation of setUp, <test method>, tearDown.
  // This is the whole reason we re-implement this method.
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  // the SenTestKit framework on iOS 5.0 does not implement most methods used here (see https://github.com/facebook/xctool/issues/334)
  // so check for that and skip the non-implemented methods if necessary

  if ([self respondsToSelector:@selector(setUpTestWithSelector:)]) {
    [self setUpTestWithSelector:selector];
  }
  [self setUp];

  BOOL supportsTestIterations = [self respondsToSelector:@selector(numberOfTestIterationsForTestWithSelector:)];

  if (supportsTestIterations) {
    NSUInteger numberOfIterations = [self numberOfTestIterationsForTestWithSelector:selector];
    for (NSUInteger i = 0; i < numberOfIterations; i++) {
      [self beforeTestIteration:i selector:selector];
      [invocation invoke];
      [self afterTestIteration:i selector:selector];
    }
  } else {
    [invocation invoke];
  }

  [self tearDown];
  if ([self respondsToSelector:@selector(tearDownTestWithSelector:)]) {
    [self tearDownTestWithSelector:selector];
  }

  [pool drain];
}

void XTApplySenTestCaseInvokeTestFix()
{
  XTSwizzleSelectorForFunction(NSClassFromString(@"SenTestCase"),
                               @selector(invokeTest),
                               (IMP)SenTestCase_invokeTest);
}
