//
//  TestProjectApplicationTestsWithSomeDisabled.h
//  TestProjectApplicationTestsWithSomeDisabled
//
//  Created by Fred Potter on 11/12/12.
//  Copyright (c) 2012 Facebook, Inc. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

@interface EnabledTestCase : SenTestCase
@end

@interface AllDisabledTestCase : SenTestCase
@end

@interface SomeDisabledTestCase : SenTestCase
@end
