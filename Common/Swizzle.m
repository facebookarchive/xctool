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

  class_addMethod(clscls, newSelector, newImp,
                  method_getTypeEncoding(originalMethod));
  Method replacedMethod = class_getClassMethod(cls, newSelector);
  method_exchangeImplementations(originalMethod, replacedMethod);

#if !__has_feature(objc_arc)
  [selectorName release];
#endif
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

  class_addMethod(cls, newSelector, newImp, typeEncoding);

  Method newMethod = class_getInstanceMethod(cls, newSelector);
  method_exchangeImplementations(originalMethod, newMethod);

#if !__has_feature(objc_arc)
  [selectorName release];
#endif
}
