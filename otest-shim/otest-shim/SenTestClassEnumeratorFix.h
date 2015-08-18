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
 The implementation for `-[SenTestClassEnumerator init]` uses objc_getClassList
 to retrieve the list of Obj-C classes.  It first calls objc_getClassList to
 get the count of classes, then allocates a buffer of that size, then calls
 objc_getClassList again to retrieve all the classes (and that's the problem).

 In between `-[SenTestClassEnumerator init]`'s two calls to objc_getClassList,
 background threads can trigger more classes to be registered.  Unfortunately,
 the implementation throws an exception if the two counts returned by
 objc_getClassList don't match.

 Let's swizzle `init` and provide our own impementation that uses
 objc_copyClassList instead, which will return the class list in one shot.
 This is exactly what XCTest now does.

 More info:
 https://github.com/facebook/xctool/issues/257
 */
void XTApplySenTestClassEnumeratorFix();
