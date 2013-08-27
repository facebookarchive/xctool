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
#import <objc/objc-runtime.h>
#import <objc/runtime.h>
#import <stdio.h>

@implementation OtestQuery

+ (void)run
{
  NSString *testBundlePath = [[[NSProcessInfo processInfo] arguments] lastObject];
  NSBundle *bundle = [NSBundle bundleWithPath:testBundlePath];
  [bundle load];

  [[NSBundle allFrameworks] makeObjectsPerformSelector:@selector(principalClass)];
  NSArray *testClasses = objc_msgSend(NSClassFromString(@"SenTestCase"), @selector(senAllSubclasses));

  NSMutableArray *testNames = [NSMutableArray array];
  for (Class testClass in testClasses) {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(testClass, &methodCount);

    for (int i = 0; i < methodCount; i++) {
      NSString *methodName = [NSString stringWithUTF8String:sel_getName(method_getName(methods[i]))];
      if ([methodName hasPrefix:@"test"]) {
        [testNames addObject:[NSString stringWithFormat:@"%@/%@", testClass, methodName]];
      }
    }
  }

  [testNames sortUsingSelector:@selector(compare:)];

  NSData *json = [NSJSONSerialization dataWithJSONObject:testNames options:0 error:nil];
  [(NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput] writeData:json];
}

@end
