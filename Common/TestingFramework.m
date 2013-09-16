//
//  TestingFramework.m
//  xctool
//
//  Created by Ryan Rhee on 9/11/13.
//  Copyright (c) 2013 Fred Potter. All rights reserved.
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
    NSLog(@"The bundle extension %@ is not supported. The supported extensions are: %@. Defaulting to use SenTestingKit instead.",
          extension, [frameworks allKeys]);
    return [[self class] SenTestingKit];
  }
  return [frameworks objectForKey:extension];
}

+ (instancetype)frameworkForTestBundleAtPath: (NSString *)path
{
  NSString *extension = [path pathExtension];
  return [self frameworkForExtension:extension];
}

@end
