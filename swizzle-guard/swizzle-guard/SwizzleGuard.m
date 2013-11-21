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

#import "SwizzleGuard.h"
#import "SwizzleGuardInternal.h"

#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "dyld-interposing.h"

#pragma mark State

static BOOL __swizzleGuardEnabled = NO;

static NSMutableDictionary *__IMPRestoreRecords = nil;
static NSMutableArray *__MethodAddedRecords = nil;

#pragma mark Prototypes

static Method MethodForClassAndSEL(Class cls, SEL name);
static void MakeOrClearIMPRestoreRecord(Method method, IMP newImp);

#pragma mark Interposed Hooks

static void __method_exchangeImplementations(Method m1, Method m2)
{
  if (__swizzleGuardEnabled) {
    IMP imp1 = method_getImplementation(m1);
    IMP imp2 = method_getImplementation(m2);

    MakeOrClearIMPRestoreRecord(m1, imp2);
    MakeOrClearIMPRestoreRecord(m2, imp1);
  }
  return method_exchangeImplementations(m1, m2);
}
DYLD_INTERPOSE(__method_exchangeImplementations, method_exchangeImplementations);

static IMP __method_setImplementation(Method method, IMP imp)
{
  if (__swizzleGuardEnabled) {
    MakeOrClearIMPRestoreRecord(method, imp);
  }
  return method_setImplementation(method, imp);
}
DYLD_INTERPOSE(__method_setImplementation, method_setImplementation);

static IMP __class_replaceMethod(Class cls, SEL name, IMP imp, const char *types)
{
  if (__swizzleGuardEnabled) {
    Method method = MethodForClassAndSEL(cls, name);

    if (method) {
      // The method already existed; save the original.
      MakeOrClearIMPRestoreRecord(method, imp);
    } else {
      // class_replaceMethod is going to end up adding a method; make a note.
      XTMethodAddedRecord *record = [[[XTMethodAddedRecord alloc] init] autorelease];
      record.cls = cls;
      record.name = name;
      record.imp = imp;
      [__MethodAddedRecords addObject:record];
    }
  }
  return class_replaceMethod(cls, name, imp, types);
}
DYLD_INTERPOSE(__class_replaceMethod, class_replaceMethod);

static BOOL __class_addMethod(Class cls, SEL name, IMP imp, const char *types)
{
  if (__swizzleGuardEnabled) {
    XTMethodAddedRecord *record = [[[XTMethodAddedRecord alloc] init] autorelease];
    record.cls = cls;
    record.name = name;
    record.imp = imp;
    [__MethodAddedRecords addObject:record];
  }
  return class_addMethod(cls, name, imp, types);
}
DYLD_INTERPOSE(__class_addMethod, class_addMethod);


#pragma mark Implementation

static void MakeOrClearIMPRestoreRecord(Method method, IMP newImp)
{
  id key = [NSValue valueWithPointer:method];
  XTIMPRestoreRecord *record = [__IMPRestoreRecords objectForKey:key];

  if (record == nil) {
    // Save info about the original implementation so we can restore it later.
    record = [[[XTIMPRestoreRecord alloc] init] autorelease];
    record.method = method;
    record.originalIMP = method_getImplementation(method);

    [__IMPRestoreRecords setObject:record forKey:key];
  } else if (record != nil && record.originalIMP == newImp) {
    // The caller is setting it back to the original IMP, so we don't need to
    // restore later.
    [__IMPRestoreRecords removeObjectForKey:key];
    record = nil;
  }
}

static Method MethodForClassAndSEL(Class cls, SEL name)
{
  Method match = NULL;
  unsigned int count = 0;
  Method *methods = class_copyMethodList(cls, &count);

  for (unsigned int i = 0; i < count; i++) {
    Method method = methods[i];

    if (sel_isEqual(method_getName(method), name)) {
      match = method;
      break;
    }
  }

  free(methods);
  return match;
}

static void RestoreOriginals()
{
  for (XTIMPRestoreRecord *record in XTSwizzleGuardIMPRestoreRecords()) {
    method_setImplementation(record.method, record.originalIMP);
  }
}

void XTSwizzleGuardEnable()
{
  __swizzleGuardEnabled = YES;
  __IMPRestoreRecords = [[NSMutableDictionary alloc] init];
  __MethodAddedRecords = [[NSMutableArray alloc] init];
}

void XTSwizzleGuardDisable()
{
  __swizzleGuardEnabled = NO;

  RestoreOriginals();

  [__IMPRestoreRecords release];
  __IMPRestoreRecords = nil;
  [__MethodAddedRecords release];
  __MethodAddedRecords = nil;
}

static NSString *SymbolNameForIMP(IMP imp)
{
  Dl_info dl_info = {0};
  int result = dladdr(imp, &dl_info);

  if (result != 0 && dl_info.dli_sname != NULL) {
    return [NSString stringWithUTF8String:dl_info.dli_sname];
  } else {
    return nil;
  }
}

NSArray *XTSwizzleGuardIMPRestoreRecords()
{
  // Return in a stable order so it's easier to test.
  return [[__IMPRestoreRecords allValues] sortedArrayUsingComparator:
          ^(XTIMPRestoreRecord *a, XTIMPRestoreRecord *b){
            NSString *aName = SymbolNameForIMP([a originalIMP]);
            NSString *bName = SymbolNameForIMP([b originalIMP]);
            return [aName compare:bName];
          }];
}

NSArray *XTSwizzleGuardMethodAddedRecords()
{
  return __MethodAddedRecords;
}

NSString *XTSwizzleGuardStateDescription()
{
  NSArray *records = XTSwizzleGuardIMPRestoreRecords();
  NSArray *methodAddedRecords = XTSwizzleGuardMethodAddedRecords();
  if ([records count] > 0 ||
      [methodAddedRecords count] > 0) {
    NSMutableString *str = [NSMutableString string];

    for (XTIMPRestoreRecord *record in records) {
      [str appendFormat:@"'%@' was swizzled with '%@', but never restored. (will be undone)\n",
       SymbolNameForIMP(record.originalIMP),
       SymbolNameForIMP(method_getImplementation(record.method))];
    }

    for (XTMethodAddedRecord *record in methodAddedRecords) {
      [str appendFormat:@"'-[%s %s]' was added with IMP '%@'. (cannot be undone)\n",
       class_getName(record.cls),
       sel_getName(record.name),
       SymbolNameForIMP(record.imp)];
    }

    return str;
  } else {
    return nil;
  }
}

@implementation XTIMPRestoreRecord

@synthesize method = _method;
@synthesize originalIMP = _originalIMP;

@end

@implementation XTMethodAddedRecord

@synthesize cls = _cls;
@synthesize name = _name;
@synthesize imp = _imp;

@end

