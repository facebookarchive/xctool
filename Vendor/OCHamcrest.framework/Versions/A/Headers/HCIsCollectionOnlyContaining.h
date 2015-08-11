//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCEvery.h>


@interface HCIsCollectionOnlyContaining : HCEvery

+ (instancetype)isCollectionOnlyContaining:(id <HCMatcher>)matcher;

@end


FOUNDATION_EXPORT id HC_onlyContains(id itemMatch, ...) NS_REQUIRES_NIL_TERMINATION;

/**
 onlyContains(firstMatcher, ...) -
 Matches if each element of collection satisfies any of the given matchers.

 @param firstMatcher,...  A comma-separated list of matchers ending with @c nil.

 This matcher iterates the evaluated collection, confirming whether each element satisfies any of
 the given matchers.

 Any argument that is not a matcher is implicitly wrapped in an @ref equalTo matcher to check for
 equality.

 Example:

 @par
 @ref onlyContains(startsWith(@"Jo"), nil)

 will match a collection [@"Jon", @"John", @"Johann"].

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_onlyContains instead.)

 @ingroup collection_matchers
 */
#ifdef HC_SHORTHAND
    #define onlyContains HC_onlyContains
#endif
