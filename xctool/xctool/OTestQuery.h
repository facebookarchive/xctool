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
 * Returns a list of all classes inheriting from SenTestCase in the bundle.
 *
 * @param bundlePath Path to OCUnit test bundle (ending in .octest)
 * @param sdk SDK to use (e.g. iphonesimulator6.1)
 */
NSArray *OTestQueryTestCasesInIOSBundle(NSString *bundlePath, NSString *sdk);

/**
 * Returns a list of all classes inheriting from SenTestCase in the bundle.
 *
 * @param bundlePath Path to OCUnit test bundle (ending in .octest)
 * @param builtProductsDir Used to set a couple DYLD environment variables.  This
 *   path would normally be something like '.../Build/Products/Debug".
 * @param disableGC If YES, OBJC_DISABLE_GC will be set to YES.
 */
NSArray *OTestQueryTestCasesInOSXBundle(NSString *bundlePath, NSString *builtProductsDir, BOOL disableGC);
