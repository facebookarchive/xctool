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
#define TF_TESTRUNNER_NAME @"executable"
#define TF_INVERT_SCOPE_ARG_KEY @"invertScope"
#define TF_FILTER_TESTS_ARG_KEY @"filterTestcasesArg"

#define WRAPPER_EXTENSION_KEY @"WRAPPER_EXTENSION"

@interface TestingFramework ()

@property (nonatomic, retain) NSString *testClassName;
@property (nonatomic, retain) NSString *allTestSelectorName;
@property (nonatomic, retain) NSString *testRunnerPath;
@property (nonatomic, retain) NSString *filterTestsArgKey;
@property (nonatomic, retain) NSString *invertScopeArgKey;


@end

NSDictionary *getWrapperToFrameworkMapping() {
  // Only set this once. Easy optimization!
  static NSDictionary *wrapperToFrameworkMapping = nil;
  
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    wrapperToFrameworkMapping = @{
      @"octest": @{
        TF_CLASS_NAME: @"SenTestCase",
        TF_ALL_TESTS_SELECTOR_NAME: @"senAllSubclasses",
        TF_TESTRUNNER_NAME: @"Tools/otest",
        TF_FILTER_TESTS_ARG_KEY: @"-SenTest",
        TF_INVERT_SCOPE_ARG_KEY: @"-SenTestInvertScope"
      },
      @"xctest": @{
        TF_CLASS_NAME: @"XCTestCase",
        TF_ALL_TESTS_SELECTOR_NAME: @"xct_allSubclasses",
        TF_TESTRUNNER_NAME: @"usr/bin/xctest",
        TF_FILTER_TESTS_ARG_KEY: @"-XCTest",
        TF_INVERT_SCOPE_ARG_KEY: @"-XCTestInvertScope"
      }
    };
    [wrapperToFrameworkMapping retain];
  });
  return wrapperToFrameworkMapping;
}

@implementation TestingFramework

@synthesize testClassName, allTestSelectorName, testRunnerPath, filterTestsArgKey, invertScopeArgKey;

+ (NSDictionary *)frameworkInfoForBuildSettings: (NSDictionary *)testableBuildSettings
{
  NSString *wrapperExtension = nil;
  
  if (![[testableBuildSettings allKeys] containsObject:WRAPPER_EXTENSION_KEY]
      || [[testableBuildSettings objectForKey:WRAPPER_EXTENSION_KEY] isEqualToString:@""]) {
    NSLog(@"The %@ key isn't set or its value is empty in the build settings for this project. Defaulting to SenTestingKit.", WRAPPER_EXTENSION_KEY);
    wrapperExtension = @"octest";
  } else {
    wrapperExtension = [testableBuildSettings objectForKey:WRAPPER_EXTENSION_KEY];
  }
  
  return [self frameworkInfoForWrapperExtension: wrapperExtension];
}

+ (NSDictionary *)frameworkInfoForWrapperExtension: (NSString *)wrapperExtension
{
  NSDictionary *wrapperToFrameworkMapping = getWrapperToFrameworkMapping();
  if (![[wrapperToFrameworkMapping allKeys] containsObject:wrapperExtension]) {
    NSLog(@"The wrapper extension %@ is not supported. The supported extensions are: %@",
          wrapperExtension, [wrapperToFrameworkMapping allKeys]);
    abort();
  }
  
  return [wrapperToFrameworkMapping objectForKey:wrapperExtension];
}

+ (instancetype)XCTest
{
  return [[[self alloc] initWithBundleExtension:@"xctest"] autorelease];
}

+ (instancetype)SenTestingKit
{
  return [[[self alloc] initWithBundleExtension:@"octest"] autorelease];
}

- (id)initWithBundleExtension: (NSString *)extension;
{
  if (self = [super init]) {
    NSDictionary *frameworkInfo = [[self class] frameworkInfoForWrapperExtension:extension];
    self.testClassName        = [frameworkInfo objectForKey:TF_CLASS_NAME];
    self.allTestSelectorName  = [frameworkInfo objectForKey:TF_ALL_TESTS_SELECTOR_NAME];
    self.testRunnerPath       = [frameworkInfo objectForKey:TF_TESTRUNNER_NAME];
    self.filterTestsArgKey    = [frameworkInfo objectForKey:TF_FILTER_TESTS_ARG_KEY];
    self.invertScopeArgKey    = [frameworkInfo objectForKey:TF_INVERT_SCOPE_ARG_KEY];
  }
  return self;
}

@end
