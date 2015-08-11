//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCBaseMatcher.h>


@interface HCIsNot : HCBaseMatcher

+ (instancetype)isNot:(id <HCMatcher>)matcher;
- (instancetype)initNot:(id <HCMatcher>)matcher;

@end


FOUNDATION_EXPORT id HC_isNot(id aMatcher);

/**
 isNot(aMatcher) -
 Inverts the given matcher to its logical negation.

 @param aMatcher  The matcher to negate.

 This matcher compares the evaluated object to the negation of the given matcher. If the
 @a aMatcher argument is not a matcher, it is implicitly wrapped in an @ref equalTo matcher to
 check for equality, and thus matches for inequality.

 Examples:
 @li <code>@ref assertThat(cheese, isNot(equalTo(smelly)))</code>
 @li <code>@ref assertThat(cheese, isNot(smelly))</code>

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_isNot instead.)

 @ingroup logical_matchers
 */
#ifdef HC_SHORTHAND
    #define isNot HC_isNot
#endif
