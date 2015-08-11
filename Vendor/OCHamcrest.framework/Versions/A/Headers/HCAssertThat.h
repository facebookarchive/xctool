//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <Foundation/Foundation.h>

@protocol HCMatcher;


FOUNDATION_EXPORT void HC_assertThatWithLocation(id testCase, id actual, id <HCMatcher> matcher,
                                                 const char *fileName, int lineNumber);

#define HC_assertThat(actual, matcher)  \
    HC_assertThatWithLocation(self, actual, matcher, __FILE__, __LINE__)

/**
 assertThat(actual, matcher) -
 Asserts that actual value satisfies matcher.

 @param actual   The object to evaluate as the actual value.
 @param matcher  The matcher to satisfy as the expected condition.

 @c assertThat passes the actual value to the matcher for evaluation. If the matcher is not
 satisfied, an exception is thrown describing the mismatch.

 @c assertThat is designed to integrate well with OCUnit and other unit testing frameworks.
 Unmet assertions are reported as test failures. In Xcode, these failures can be clicked to
 reveal the line of the assertion.

 In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_assertThat instead.

 @ingroup integration
 */
#ifdef HC_SHORTHAND
    #define assertThat HC_assertThat
#endif


typedef id (^HCAssertThatAfterActualBlock)();

OBJC_EXPORT void HC_assertThatAfterWithLocation(id testCase, NSTimeInterval maxTime,
                                                HCAssertThatAfterActualBlock actualBlock,
                                                id<HCMatcher> matcher,
                                                const char *fileName, int lineNumber);

#define HC_assertThatAfter(maxTime, actualBlock, matcher)  \
    HC_assertThatAfterWithLocation(self, maxTime, actualBlock, matcher, __FILE__, __LINE__)

#define HC_futureValueOf(actual) ^{ return actual; }

/**
 assertThatAfter(maxTime, actualBlock, matcher) -
 Asserts that a value provided by a block will satisfy matcher in less than a given time.

 @param maxTime     Max time (in seconds) in which the matcher has to be satisfied.
 @param actualBlock A block providing the object to evaluate until timeout or the matcher is satisfied.
 @param matcher     The matcher to satisfy as the expected condition.

 @c assertThatAfter checks several times if the matcher is satisfied before timeout. To evaluate the
 matcher, the @c actualBlock will provide updated values of actual. If the matcher is not satisfied
 after @c maxTime, an exception is thrown describing the mismatch. An easy way of defining this
 @c actualBlock is using the macro <code>futureValueOf(actual)</code>, which also improves
 readability.

 In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_assertThatAfter and HC_futureValueOf instead.

 @ingroup integration
*/
#ifdef HC_SHORTHAND
    #define assertThatAfter HC_assertThatAfter
    #define futureValueOf HC_futureValueOf
#endif
