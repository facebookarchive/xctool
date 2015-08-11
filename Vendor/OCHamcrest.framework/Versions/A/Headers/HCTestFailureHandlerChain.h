//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <Foundation/Foundation.h>

@class HCTestFailureHandler;


/**
 Returns chain of test failure handlers.

 @ingroup integration
 */
FOUNDATION_EXPORT HCTestFailureHandler *HC_testFailureHandlerChain(void);
