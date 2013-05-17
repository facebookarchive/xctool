
#import <Foundation/Foundation.h>

@interface SwizzleReceipt : NSObject
{
@public
  IMP _originalIMP;
  SEL _sel;
  Class _cls;
}

@end

@interface Swizzler : NSObject

/**
 Swizzles instance method; returns a receipt that you can use to later
 undo the swizzling.
 */
+ (SwizzleReceipt *)swizzleSelector:(SEL)sel
                forInstancesOfClass:(Class)cls
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

@end
