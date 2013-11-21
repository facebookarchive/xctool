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

/**
 SwizzleGuard prevents poorly behaved tests from affecting the test runner,
 otest-shim, and other tests.  It gives us a way to reverse many swizzling 
 operations that were made during a test.
 
 It works by interposing calls to the following Obj-C runtime functions:

   - class_addMethod
   - class_replaceMethod
   - method_setImplementation
   - method_exchangeImplementations

 Whenever a method's implementation is swizzled, SwizzleGuard makes a record
 of the original implementation (IMP).  When the guard is disabled, we restore
 the original implementation.
 
 Most swizzling operations can be undone in this way.  The only exception is
 that we cannot remove a method that was added to class because the Obj-C 2.0 
 API took away the class_removeMethods function.
 */


/**
 When SwizzleGuard is enabled, many calls to the Obj-C runtime functions will
 be recorded.  Where possible, those changes will be undone when the guard is
 disabled.
 */
void XTSwizzleGuardEnable();

/**
 Disables the hooks from capturing any more calls to Obj-C runtime functions.
 Where possible, all swizzles are undone and the original implementations are
 restored.
 */
void XTSwizzleGuardDisable();

/**
 Returns a summary of all ObjC class information that was changed, and indicates
 which of those changes can be undone when the guard is disabled.
 
 We had originally thought we'd include a summary of swizzles made in test
 output as a warning to the develper.  But, it ends up being far too noisy.
 */
NSString *XTSwizzleGuardStateDescription();