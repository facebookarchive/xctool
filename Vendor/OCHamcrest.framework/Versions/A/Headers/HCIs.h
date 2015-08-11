//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCBaseMatcher.h>


@interface HCIs : HCBaseMatcher

+ (instancetype)is:(id <HCMatcher>)matcher;
- (instancetype)initWithMatcher:(id <HCMatcher>)matcher;

@end


FOUNDATION_EXPORT id HC_is(id match);

/**
 is(aMatcher) -
 Decorates another matcher, or provides a shortcut to the frequently used @ref is(equalTo(x)).

 @param aMatcher  The matcher to satisfy, or an expected value for @ref equalTo matching.

 This matcher compares the evaluated object to the given matcher.

 If the @a aMatcher argument is a matcher, its behavior is retained, but the test may be more
 expressive. For example:
 @li <code>@ref assertThat(@(value), equalTo(@5))</code>
 @li <code>@ref assertThat(@(value), is(equalTo(@5)))</code>

 If the @a aMatcher argument is not a matcher, it is wrapped in an @ref equalTo matcher. This
 makes the following statements equivalent:
 @li <code>@ref assertThat(cheese, equalTo(smelly))</code>
 @li <code>@ref assertThat(cheese, is(equalTo(smelly)))</code>
 @li <code>@ref assertThat(cheese, is(smelly))</code>

 Choose the style that makes your expression most readable. This will vary depending on context.

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_is instead.)

 @ingroup decorator_matchers
 */
#ifdef HC_SHORTHAND
    #define is HC_is
#endif
