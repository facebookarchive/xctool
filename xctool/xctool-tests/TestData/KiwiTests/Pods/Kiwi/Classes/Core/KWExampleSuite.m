//
//  KWExampleSuite.m
//  Kiwi
//
//  Created by Luke Redpath on 17/10/2011.
//  Copyright (c) 2011 Allen Ding. All rights reserved.
//

#import "KWExampleSuite.h"

#import "KWAfterAllNode.h"
#import "KWBeforeAllNode.h"
#import "KWContextNode.h"
#import "KWExample.h"
#import "KWStringUtilities.h"
#import "NSMethodSignature+KiwiAdditions.h"
#import <objc/runtime.h>

#define kKWINVOCATION_EXAMPLE_GROUP_KEY @"__KWExampleGroupKey"

@interface KWExampleSuite()

@property (nonatomic, strong) KWContextNode *rootNode;
@property (nonatomic, strong) NSMutableArray *examples;

@end

@implementation KWExampleSuite

- (id)initWithRootNode:(KWContextNode *)contextNode {
    self = [super init];
    if (self) {
        _rootNode = contextNode;
        _examples = [[NSMutableArray alloc] init];
    }
    return self;
}


- (void)addExample:(KWExample *)example {
    [self.examples addObject:example];
    example.suite = self;
}

- (void)markLastExampleAsLastInContext:(KWContextNode *)context
{
    if ([self.examples count] > 0) {
        KWExample *lastExample = (KWExample *)[self.examples lastObject];
        [lastExample.lastInContexts addObject:context];
    }
}

- (NSArray *)invocationsForTestCase {
    NSMutableArray *invocations = [NSMutableArray array];
    
    // Add a single dummy invocation for each example group
    
    for (KWExample *exampleGroup in self.examples) {
        NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:[KWEncodingForDefaultMethod() UTF8String]];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
        [invocations addObject:invocation];
        [invocation kw_setExample:exampleGroup];
    }
    
    return invocations;
}

@end

#pragma mark -

// because SenTest will modify the invocation target, we'll have to store 
// another reference to the example group so we can retrieve it later

@implementation NSInvocation (KWExampleGroup)

- (void)kw_setExample:(KWExample *)exampleGroup {
  objc_setAssociatedObject(self, kKWINVOCATION_EXAMPLE_GROUP_KEY, exampleGroup, OBJC_ASSOCIATION_RETAIN);    
}

- (KWExample *)kw_example {
    return objc_getAssociatedObject(self, kKWINVOCATION_EXAMPLE_GROUP_KEY);
}

@end

