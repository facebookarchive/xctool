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
#import <stdio.h>

// weakly loading SenTestingKit seem to cause these symbols to resolve to null
static NSString *SenTestedUnitPath_ = @"SenTestedUnitPath";
static NSString *SenTestScopeKey_ = @"SenTest";
static NSString *SenTestScopeSelf_ = @"Self";

@implementation OtestQuery

+ (void)run
{
  NSString *testBundlePath = [[[NSProcessInfo processInfo] arguments] lastObject];
  NSBundle *bundle = [NSBundle bundleWithPath:testBundlePath];
  [bundle load];

  NSString *path = [[NSBundle mainBundle] bundlePath];

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:path forKey:SenTestedUnitPath_];
  [defaults setObject:SenTestScopeSelf_ forKey:SenTestScopeKey_];

  [[NSBundle allFrameworks] makeObjectsPerformSelector:@selector(principalClass)];
  NSArray *testClasses = objc_msgSend(NSClassFromString(@"SenTestCase"), @selector(senAllSubclasses));
  NSMutableArray *testClassNames = [NSMutableArray array];
  for (Class testClass in testClasses) {
    [testClassNames addObject:[NSString stringWithUTF8String:class_getName(testClass)]];
  }
  NSData *json = [NSJSONSerialization dataWithJSONObject:testClassNames options:0 error:nil];
  [[NSFileHandle fileHandleWithStandardOutput] writeData:json];
}

@end
