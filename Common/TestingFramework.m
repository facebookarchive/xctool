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

#import "TestingFramework.h"

#define TF_CLASS_NAME @"class"
#define TF_ALL_TESTS_SELECTOR_NAME @"selector"
#define TF_IOS_TESTRUNNER_NAME @"ios_executable"
#define TF_OSX_TESTRUNNER_NAME @"osx_executable"
#define TF_INVERT_SCOPE_ARG_KEY @"invertScope"
#define TF_FILTER_TESTS_ARG_KEY @"filterTestcasesArg"

#define WRAPPER_EXTENSION_KEY @"WRAPPER_EXTENSION"

@interface TestingFramework ()

@property (nonatomic, retain) NSString *testClassName;
@property (nonatomic, retain) NSString *allTestSelectorName;
@property (nonatomic, retain) NSString *iosTestRunnerPath;
@property (nonatomic, retain) NSString *osxTestRunnerPath;
@property (nonatomic, retain) NSString *filterTestsArgKey;
@property (nonatomic, retain) NSString *invertScopeArgKey;

@end

static NSDictionary *frameworks;

@implementation TestingFramework

+ (void)initialize
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSDictionary *extensionToFrameworkInfoMapping = @{
      @"octest": @{
        TF_CLASS_NAME: @"SenTestCase",
        TF_ALL_TESTS_SELECTOR_NAME: @"senAllSubclasses",
        TF_OSX_TESTRUNNER_NAME: @"Tools/otest",
        TF_IOS_TESTRUNNER_NAME: @"usr/bin/otest",
        TF_FILTER_TESTS_ARG_KEY: @"-SenTest",
        TF_INVERT_SCOPE_ARG_KEY: @"-SenTestInvertScope"
      },
      @"xctest": @{
        TF_CLASS_NAME: @"XCTestCase",
        TF_ALL_TESTS_SELECTOR_NAME: @"xct_allSubclasses",
        TF_IOS_TESTRUNNER_NAME: @"usr/bin/xctest",
        TF_OSX_TESTRUNNER_NAME: @"usr/bin/xctest",
        TF_FILTER_TESTS_ARG_KEY: @"-XCTest",
        TF_INVERT_SCOPE_ARG_KEY: @"-XCTestInvertScope"
      }
    };
    NSMutableDictionary *_frameworks = [[NSMutableDictionary alloc] init];
    for (NSString *extension in [extensionToFrameworkInfoMapping allKeys]) {
      NSDictionary *frameworkInfo = [extensionToFrameworkInfoMapping objectForKey:extension];
      TestingFramework *framework = [[self alloc] init];
      framework.testClassName        = [frameworkInfo objectForKey:TF_CLASS_NAME];
      framework.allTestSelectorName  = [frameworkInfo objectForKey:TF_ALL_TESTS_SELECTOR_NAME];
      framework.iosTestRunnerPath    = [frameworkInfo objectForKey:TF_IOS_TESTRUNNER_NAME];
      framework.osxTestRunnerPath    = [frameworkInfo objectForKey:TF_OSX_TESTRUNNER_NAME];
      framework.filterTestsArgKey    = [frameworkInfo objectForKey:TF_FILTER_TESTS_ARG_KEY];
      framework.invertScopeArgKey    = [frameworkInfo objectForKey:TF_INVERT_SCOPE_ARG_KEY];
      [_frameworks setObject:framework forKey:extension];
      [frameworks release];
    }
    frameworks = [_frameworks copy];
    [_frameworks release];
  });
}

+ (instancetype)XCTest
{
  return [frameworks objectForKey:@"xctest"];
}

+ (instancetype)SenTestingKit
{
  return [frameworks objectForKey:@"octest"];
}

+ (instancetype)frameworkForExtension: (NSString *)extension
{
  if (![[frameworks allKeys] containsObject:extension]) {
    NSLog(@"The bundle extension %@ is not supported. The supported extensions are: %@.",
          extension, [frameworks allKeys]);
    return nil;
  }
  return [frameworks objectForKey:extension];
}

+ (instancetype)frameworkForTestBundleAtPath: (NSString *)path
{
  NSString *extension = [path pathExtension];
  return [self frameworkForExtension:extension];
}

@end
