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

#import "Swizzler.h"

#import <objc/message.h>
#import <objc/runtime.h>

@interface SwizzleReceipt : NSObject
{
@public
  Method _method;
  IMP _originalIMP;
}
@end

@implementation SwizzleReceipt
@end

@implementation Swizzler

+ (SwizzleReceipt *)_replaceMethod:(Method)method withBlock:(id)block
{
  SwizzleReceipt *receipt = [[SwizzleReceipt alloc] init];

  receipt->_method = method;
  receipt->_originalIMP = method_getImplementation(method);

  IMP blockIMP = imp_implementationWithBlock(block);

  method_setImplementation(method, blockIMP);

  return receipt;
}

+ (void)_bracket:(void (^)(void))block finally:(void (^)(void))afterBlock
{
  @try {
    block();
  }
  @catch (NSException *exception) {
    @throw exception;
  }
  @finally {
    afterBlock();
  }
}

+ (SwizzleReceipt *)swizzleSelector:(SEL)sel
                forInstancesOfClass:(Class)cls
                          withBlock:(id)block
{
  Method method = class_getInstanceMethod(cls, sel);
  NSAssert(method != NULL,
           @"class_getInstanceMethod(%s, %s) failed.",
           class_getName(cls),
           sel_getName(sel));
  return [Swizzler _replaceMethod:method withBlock:block];
}

+ (SwizzleReceipt *)swizzleSelector:(SEL)sel
                           forClass:(Class)cls
                          withBlock:(id)block
{
  Method method = class_getClassMethod(cls, sel);
  NSAssert(method != NULL,
           @"class_getClassMethod(%s, %s) failed.",
           class_getName(cls),
           sel_getName(sel));
  return [Swizzler _replaceMethod:method withBlock:block];
}

+ (void)unswizzleFromReceipt:(SwizzleReceipt *)receipt
{
  method_setImplementation(receipt->_method, receipt->_originalIMP);
}

+ (void)whileSwizzlingSelector:(SEL)sel
           forInstancesOfClass:(Class)cls
                     withBlock:(id)block
                      runBlock:(void (^)(void))runBlock
{
  SwizzleReceipt *receipt = [[self class] swizzleSelector:sel
                                      forInstancesOfClass:cls
                                                withBlock:block];
  [[self class] _bracket:runBlock finally:^{
    [[self class] unswizzleFromReceipt:receipt];
  }];
}

+ (void)whileSwizzlingSelector:(SEL)sel
                      forClass:(Class)cls
                     withBlock:(id)block
                      runBlock:(void (^)(void))runBlock
{
  SwizzleReceipt *receipt = [[self class] swizzleSelector:sel
                                                 forClass:cls
                                                withBlock:block];
  [[self class] _bracket:runBlock finally:^{
    [[self class] unswizzleFromReceipt:receipt];
  }];
}

@end
