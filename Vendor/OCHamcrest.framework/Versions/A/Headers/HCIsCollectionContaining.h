//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCDiagnosingMatcher.h>


@interface HCIsCollectionContaining : HCDiagnosingMatcher

+ (instancetype)isCollectionContaining:(id <HCMatcher>)elementMatcher;
- (instancetype)initWithMatcher:(id <HCMatcher>)elementMatcher;

@end


FOUNDATION_EXPORT id HC_hasItem(id itemMatch);

/**
 hasItem(aMatcher) -
 Matches if any element of collection satisfies a given matcher.

 @param aMatcher  The matcher to satisfy, or an expected value for @ref equalTo matching.

 This matcher iterates the evaluated collection, searching for any element that satisfies a
 given matcher. If a matching element is found, @c hasItem is satisfied.

 If the @a aMatcher argument is not a matcher, it is implicitly wrapped in an @ref equalTo
 matcher to check for equality.

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_hasItem instead.)

 @ingroup collection_matchers
 */
#ifdef HC_SHORTHAND
    #define hasItem HC_hasItem
#endif


FOUNDATION_EXPORT id HC_hasItems(id itemMatch, ...) NS_REQUIRES_NIL_TERMINATION;

/**
 hasItems(firstMatcher, ...) -
 Matches if all of the given matchers are satisfied by any elements of the collection.

 @param firstMatcher,...  A comma-separated list of matchers ending with @c nil.

 This matcher iterates the given matchers, searching for any elements in the evaluated collection
 that satisfy them. If each matcher is satisfied, then @c hasItems is satisfied.

 Any argument that is not a matcher is implicitly wrapped in an @ref equalTo matcher to check for
 equality.

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c hasItems instead.)

 @ingroup collection_matchers
 */
#ifdef HC_SHORTHAND
    #define hasItems HC_hasItems
#endif
