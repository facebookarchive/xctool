//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCInvocationMatcher.h>


@interface HCHasDescription : HCInvocationMatcher

+ (instancetype)hasDescription:(id <HCMatcher>)descriptionMatcher;
- (instancetype)initWithDescription:(id <HCMatcher>)descriptionMatcher;

@end


FOUNDATION_EXPORT id HC_hasDescription(id match);

/**
 hasDescription(aMatcher) -
 Matches if object's @c -description satisfies a given matcher.

 @param aMatcher  The matcher to satisfy, or an expected value for @ref equalTo matching.

 This matcher invokes @c -description on the evaluated object to get its description, passing the
 result to a given matcher for evaluation. If the @a aMatcher argument is not a matcher, it is
 implicitly wrapped in an @ref equalTo matcher to check for equality.

 Examples:
 @li @ref hasDescription(@ref startsWith(\@"foo"))
 @li @ref hasDescription(\@"bar")

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_hasDescription instead.)

 @ingroup object_matchers
 */
#ifdef HC_SHORTHAND
    #define hasDescription HC_hasDescription
#endif
