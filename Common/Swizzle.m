
#import "Swizzle.h"

#import <Foundation/Foundation.h>

void XTSwizzleClassSelectorForFunction(Class cls, SEL sel, IMP newImp)
{
  Class clscls = object_getClass((id)cls);
  Method originalMethod = class_getClassMethod(cls, sel);

  NSString *selectorName = [[NSString alloc] initWithFormat:
                            @"__%s_%s",
                            class_getName(cls),
                            sel_getName(sel)];
  SEL newSelector = sel_registerName([selectorName UTF8String]);
  [selectorName release];

  class_addMethod(clscls, newSelector, newImp,
                  method_getTypeEncoding(originalMethod));
  Method replacedMethod = class_getClassMethod(cls, newSelector);
  method_exchangeImplementations(originalMethod, replacedMethod);
}

void XTSwizzleSelectorForFunction(Class cls, SEL sel, IMP newImp)
{
  Method originalMethod = class_getInstanceMethod(cls, sel);
  const char *typeEncoding = method_getTypeEncoding(originalMethod);

  NSString *selectorName = [[NSString alloc] initWithFormat:
                            @"__%s_%s",
                            class_getName(cls),
                            sel_getName(sel)];
  SEL newSelector = sel_registerName([selectorName UTF8String]);
  [selectorName release];

  class_addMethod(cls, newSelector, newImp, typeEncoding);

  Method newMethod = class_getInstanceMethod(cls, newSelector);
  method_exchangeImplementations(originalMethod, newMethod);
}
