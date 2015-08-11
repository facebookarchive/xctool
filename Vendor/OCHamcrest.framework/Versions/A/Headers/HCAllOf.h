//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCDiagnosingMatcher.h>


@interface HCAllOf : HCDiagnosingMatcher

+ (instancetype)allOf:(NSArray *)matchers;
- (instancetype)initWithMatchers:(NSArray *)matchers;

@end


FOUNDATION_EXPORT id HC_allOf(id match, ...) NS_REQUIRES_NIL_TERMINATION;

/**
 allOf(firstMatcher, ...) -
 Matches if all of the given matchers evaluate to @c YES.

 @param firstMatcher,...  A comma-separated list of matchers ending with @c nil.

 The matchers are evaluated from left to right using short-circuit evaluation, so evaluation
 stops as soon as a matcher returns @c NO.

 Any argument that is not a matcher is implicitly wrapped in an @ref equalTo matcher to check for
 equality.

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_allOf instead.)

 @ingroup logical_matchers
 */
#ifdef HC_SHORTHAND
    #define allOf HC_allOf
#endif
