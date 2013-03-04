
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

static void SwizzleSelectorForFunction(Class cls, SEL sel, IMP newImp)
{
  Method originalMethod = class_getInstanceMethod(cls, sel);
  const char *typeEncoding = method_getTypeEncoding(originalMethod);
  
  NSString *newSelectorName = [NSString stringWithFormat:@"__%s_%s", class_getName(cls), sel_getName(sel)];
  SEL newSelector = sel_registerName([newSelectorName UTF8String]);
  class_addMethod(cls, newSelector, newImp, typeEncoding);
  
  Method newMethod = class_getInstanceMethod(cls, newSelector);
  method_exchangeImplementations(originalMethod, newMethod);
}

static NSArray *IDEBuildSchemeAction_buildablesForAllSchemeCommandsIncludingDependencies(id self, SEL cmd, BOOL arg)
{
  NSArray *result = objc_msgSend(self, sel_getUid("__IDEBuildSchemeAction_buildablesForAllSchemeCommandsIncludingDependencies:"), NO);
  NSLog(@"IDEBuildSchemeAction_buildablesForAllSchemeCommandsIncludingDependencies: %d >> %@", arg, result);
  
  NSMutableArray *newResult = [NSMutableArray array];
  for (id obj in result) {
    if ([[obj description] rangeOfString:@"Facebook.app"].length > 0) {
      [newResult addObject:obj];
    }
  }
  
  NSLog(@"New result: %@", newResult);
  NSLog(@"New result: %@", [newResult[0] class]);
  NSLog(@"New result: %@", [NSBundle bundleForClass:[newResult[0] class]]);
  NSLog(@"New result: %@", [newResult[0] buildableIdentifier]);
  NSLog(@"New result: %@", [[newResult[0] xcode3Target] name]);
  
  
  return newResult;
}

__attribute__((constructor)) static void EntryPoint()
{  
  SwizzleSelectorForFunction(NSClassFromString(@"IDEBuildSchemeAction"),
                             @selector(buildablesForAllSchemeCommandsIncludingDependencies:),
                             (IMP)IDEBuildSchemeAction_buildablesForAllSchemeCommandsIncludingDependencies);

  // Unset so we don't cascade into other process that get spawned from xcodebuild.
  unsetenv("DYLD_INSERT_LIBRARIES");
}