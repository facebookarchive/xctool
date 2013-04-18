//
//  TestProjectApplicationTestsWithSomeDisabled.m
//  TestProjectApplicationTestsWithSomeDisabled
//
//  Created by Fred Potter on 11/12/12.
//  Copyright (c) 2012 Facebook, Inc. All rights reserved.
//

#import "TestProjectApplicationTestsWithSomeDisabled.h"

char ***_NSGetArgv(void);
int *_NSGetArgc(void);

@implementation EnabledTestCase

- (void)testEnabledThisPasses
{
  NSLog(@"testEnabledThisPasses");
}

- (void)testEnabledThisAlsoPasses
{
  NSLog(@"testEnabledThisAlsoPasses");

  int argc = *_NSGetArgc();
  char **argv = *_NSGetArgv();

  for (int i = 0; i < argc; i++) {
    printf("i = %d >> %s\n", i, argv[i]);
  }
}

@end

@implementation AllDisabledTestCase

- (void)testAllDisabledThisPasses
{
  NSLog(@"testAllDisabledThisPasses");
}

- (void)testAllDisabledThisAlsoPasses
{
  NSLog(@"testAllDisabledThisAlsoPasses");
}

@end

@implementation SomeDisabledTestCase

- (void)testSomeDisabledOn
{
  NSLog(@"testSomeDisabledOn");
}

- (void)testSomeDisabledOff
{
  NSLog(@"testSomeDisabledOff");
}

@end
