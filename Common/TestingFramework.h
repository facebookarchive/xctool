//
//  TestingFramework.h
//  xctool
//
//  Created by Ryan Rhee on 9/11/13.
//  Copyright (c) 2013 Fred Potter. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TestingFramework : NSObject

@property (nonatomic, readonly) NSString *testClassName;
@property (nonatomic, readonly) NSString *allTestSelectorName;
@property (nonatomic, readonly) NSString *testRunnerPath;
@property (nonatomic, readonly) NSString *filterTestsArgKey;
@property (nonatomic, readonly) NSString *invertScopeArgKey;

- (id)initWithBundleExtension: (NSString *)extension;
+ (instancetype)XCTest;
+ (instancetype)SenTestingKit;

@end
