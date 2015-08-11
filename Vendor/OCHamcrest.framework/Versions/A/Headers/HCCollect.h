//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <Foundation/Foundation.h>

#import <stdarg.h>

@protocol HCMatcher;


/**
 Returns an array of values from a variable-length comma-separated list terminated by @c nil.

 @ingroup helpers
*/
FOUNDATION_EXPORT NSMutableArray *HCCollectItems(id item, va_list args);

/**
 Returns an array of matchers from a variable-length comma-separated list terminated by @c nil.

 Each item is wrapped in HCWrapInMatcher to transform non-matcher items into equality matchers.

 @ingroup helpers
*/
FOUNDATION_EXPORT NSMutableArray *HCCollectMatchers(id item, va_list args);

/**
 Returns an array of wrapped items from a variable-length comma-separated list terminated by @c nil.

 Each item is transformed by passing it to the given @c wrap function.

 @ingroup helpers
*/
FOUNDATION_EXPORT NSMutableArray *HCCollectWrappedItems(id item, va_list args, id (*wrap)(id));
