//
//  TestingFramework.m
//  xctool
//
//  Created by Ryan Rhee on 9/11/13.
//  Copyright (c) 2013 Fred Potter. All rights reserved.
//

#import "TestingFramework.h"

#define TESTING_FRAMEWORK_CLASS_KEY @"class"
#define TESTING_FRAMEWORK_SELECTOR_KEY @"selector"
#define WRAPPER_EXTENSION_KEY @"WRAPPER_EXTENSION"

@interface TestingFramework ()

@property (nonatomic, retain) NSString *unitTestClassName;
@property (nonatomic, retain) NSString *unitTestSelectorName;

@end

NSDictionary *getWrapperToFrameworkMapping() {
  // Only set this once. Easy optimization!
  static NSDictionary *wrapperToFrameworkMapping = nil;
  
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    wrapperToFrameworkMapping = @{
                                  @"octest": @{
                                      TESTING_FRAMEWORK_CLASS_KEY: @"SenTestCase",
                                      TESTING_FRAMEWORK_SELECTOR_KEY: @"senAllSubclasses"
                                      },
                                  @"xctest": @{
                                      TESTING_FRAMEWORK_CLASS_KEY: @"XCTestCase",
                                      TESTING_FRAMEWORK_SELECTOR_KEY: @"xct_allSubclasses"
                                      }
                                  };
    [wrapperToFrameworkMapping retain];
  });
  return wrapperToFrameworkMapping;
}

@implementation TestingFramework

+ (NSDictionary *)frameworkInfoForBuildSettings: (NSDictionary *)testableBuildSettings
{
  NSString *wrapperExtension = nil;
  
  if (![[testableBuildSettings allKeys] containsObject:WRAPPER_EXTENSION_KEY] || [testableBuildSettings[WRAPPER_EXTENSION_KEY] isEqualToString:@""]) {
    NSLog(@"The %@ key isn't set or its value is empty in the build settings for this project. Defaulting to SenTestingKit.", WRAPPER_EXTENSION_KEY);
    wrapperExtension = @"octest";
  } else {
    wrapperExtension = testableBuildSettings[WRAPPER_EXTENSION_KEY];
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
  
  return wrapperToFrameworkMapping[wrapperExtension];
}

+ (NSString *)classNameFromBundleExtension: (NSString *)extension
{
  return [self frameworkInfoForWrapperExtension: extension][TESTING_FRAMEWORK_CLASS_KEY];
}

+ (NSString *)selectorNameFromBundleExtension: (NSString *)extension
{
  return [self frameworkInfoForWrapperExtension: extension][TESTING_FRAMEWORK_SELECTOR_KEY];
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
    self.unitTestClassName = [[self class] classNameFromBundleExtension: extension];
    self.unitTestSelectorName = [[self class] selectorNameFromBundleExtension: extension];
  }
  return self;
}

@end
