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

@class SwizzleReceipt;

@interface Swizzler : NSObject

/**
 Swizzles instance method; returns a receipt that you can use to later
 undo the swizzling.
 */
+ (SwizzleReceipt *)swizzleSelector:(SEL)sel
                forInstancesOfClass:(Class)cls
                          withBlock:(id)block;
/**
 Swizzles class method; returns a receipt for unswizzling.
 */
+ (SwizzleReceipt *)swizzleSelector:(SEL)sel
                           forClass:(Class)cls
                          withBlock:(id)block;

/**
 Undoes an earlier swizzling.
 */
+ (void)unswizzleFromReceipt:(SwizzleReceipt *)receipt;

/**
 A convenient wrapper that will swizzle a method, run a block, then undo
 the swizzling before returning.
 */
+ (void)whileSwizzlingSelector:(SEL)sel
           forInstancesOfClass:(Class)cls
                     withBlock:(id)block
                      runBlock:(void (^)(void))runBlock;

+ (void)whileSwizzlingSelector:(SEL)sel
                      forClass:(Class)cls
                     withBlock:(id)block
                      runBlock:(void (^)(void))runBlock;

@end
