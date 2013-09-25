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


#import "OtestQuery.h"

#import <dlfcn.h>
#import <objc/objc-runtime.h>
#import <objc/runtime.h>
#import <stdio.h>

#import "TestingFramework.h"

@implementation OtestQuery

+ (void)queryTestBundlePath:(NSString *)testBundlePath
{
  NSBundle *bundle = [NSBundle bundleWithPath:testBundlePath];
  if (!bundle) {
    fprintf(stderr, "Bundle '%s' does not identify an accessible bundle directory.\n",
            [testBundlePath UTF8String]);
    exit(kBundleOpenError);
  }

  NSDictionary *framework = FrameworkInfoForTestBundleAtPath(testBundlePath);
  if (!framework) {
    const char *bundleExtension = [[testBundlePath pathExtension] UTF8String];
    fprintf(stderr, "The bundle extension '%s' is not supported.\n", bundleExtension);
    exit(kUnsupportedFramework);
  }

  // We use dlopen() instead of -[NSBundle loadAndReturnError] because, if
  // something goes wrong, dlerror() gives us a much more helpful error message.
  if (dlopen([[bundle executablePath] UTF8String], RTLD_NOW) == NULL) {
    fprintf(stderr, "%s\n", dlerror());
    exit(kDLOpenError);
  }

  [[NSBundle allFrameworks] makeObjectsPerformSelector:@selector(principalClass)];

  Class testClass = NSClassFromString([framework objectForKey:kTestingFrameworkClassName]);
  SEL allTestsSelector = NSSelectorFromString([framework objectForKey:kTestingFrameworkAllTestsSelectorName]);
  if (testClass == nil) {
    fprintf(stderr, "The framework test class '%s' was not loaded, the framework is probably not installed on this system.\n",
            [[framework objectForKey:kTestingFrameworkClassName] UTF8String]);
    exit(kClassLoadingError);
  }
  NSArray *testClasses = objc_msgSend(testClass, allTestsSelector);

  NSMutableArray *testNames = [NSMutableArray array];
  for (Class testClass in testClasses) {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(testClass, &methodCount);

    for (int i = 0; i < methodCount; i++) {
      Method method = methods[i];
      NSString *methodName = [NSString stringWithUTF8String:sel_getName(method_getName(method))];
      unsigned int argCount = method_getNumberOfArguments(method);
      char returnType[256];
      method_getReturnType(method, returnType, 256);
      if ([methodName hasPrefix:@"test"] && argCount == 2 && strncmp(returnType, "v", 256) == 0) {
        [testNames addObject:[NSString stringWithFormat:@"%@/%@", testClass, methodName]];
      }
    }
  }

  [testNames sortUsingSelector:@selector(compare:)];

  NSData *json = [NSJSONSerialization dataWithJSONObject:testNames options:0 error:nil];
  [(NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput] writeData:json];
  exit(kSuccess);
}

@end
