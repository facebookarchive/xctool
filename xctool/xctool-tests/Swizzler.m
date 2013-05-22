
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
  SwizzleReceipt *receipt = [[[SwizzleReceipt alloc] init] autorelease];

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
