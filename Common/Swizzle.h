
#import <objc/message.h>
#import <objc/runtime.h>

void XTSwizzleClassSelectorForFunction(Class cls, SEL sel, IMP newImp);
void XTSwizzleSelectorForFunction(Class cls, SEL sel, IMP newImp);