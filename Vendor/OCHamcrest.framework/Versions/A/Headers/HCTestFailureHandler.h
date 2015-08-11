//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <Foundation/Foundation.h>

@class HCTestFailure;


/**
 Chain-of-responsibility for handling test failures.

 @ingroup integration
 */
@interface HCTestFailureHandler : NSObject

- (instancetype)initWithSuccessor:(HCTestFailureHandler *)successor;

/**
 Handle test failure at specific location, or pass to successor.
 */
- (void)handleFailure:(HCTestFailure *)failure;

@end
