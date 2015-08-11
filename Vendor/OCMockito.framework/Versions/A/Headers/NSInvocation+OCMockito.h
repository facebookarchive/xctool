//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 Jonathan M. Reid. See LICENSE.txt

#import <Foundation/Foundation.h>

@interface NSInvocation (OCMockito)

- (NSArray *)mkt_arguments;
- (void)mkt_setReturnValue:(id)returnValue;
- (void)mkt_retainArgumentsWithWeakTarget;

@end
