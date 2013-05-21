
#import "Swizzler.h"

#import <objc/message.h>
#import <objc/runtime.h>

@implementation SwizzleReceipt
@end

@implementation Swizzler

+ (SwizzleReceipt *)swizzleSelector:(SEL)sel
                forInstancesOfClass:(Class)cls
                          withBlock:(id)block
{
  Method method = class_getInstanceMethod(cls, sel);
  NSAssert(method != NULL,
           @"class_getInstanceMethod(%s, %s) failed.",
           class_getName(cls),
           sel_getName(sel));
  const char *methodTypes = method_getTypeEncoding(method);

  SwizzleReceipt *receipt = [[[SwizzleReceipt alloc] init] autorelease];

  receipt->_originalIMP = class_getMethodImplementation(cls, sel);
  receipt->_sel = sel;
  receipt->_cls = cls;

  IMP blockIMP = imp_implementationWithBlock(block);

  class_replaceMethod(cls, sel, blockIMP, methodTypes);

  return receipt;
}

+ (void)unswizzleFromReceipt:(SwizzleReceipt *)receipt
{
  Method method = class_getInstanceMethod(receipt->_cls, receipt->_sel);
  NSAssert(method != NULL,
           @"class_getInstanceMethod(%s, %s) failed.",
           class_getName(receipt->_cls),
           sel_getName(receipt->_sel));
  const char *methodTypes = method_getTypeEncoding(method);

  class_replaceMethod(receipt->_cls,
                      receipt->_sel,
                      receipt->_originalIMP,
                      methodTypes);
}

+ (void)whileSwizzlingSelector:(SEL)sel
           forInstancesOfClass:(Class)cls
                     withBlock:(id)block
                      runBlock:(void (^)(void))runBlock
{
  SwizzleReceipt *receipt = [[self class] swizzleSelector:sel
                                      forInstancesOfClass:cls
                                                withBlock:block];
  @try {
    runBlock();
  }
  @catch (NSException *exception) {
    @throw exception;
  }
  @finally {
    [[self class] unswizzleFromReceipt:receipt];
  }
}

@end
