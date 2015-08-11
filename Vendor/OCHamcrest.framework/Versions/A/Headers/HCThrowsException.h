//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCDiagnosingMatcher.h>


@interface HCThrowsException : HCDiagnosingMatcher

- (id)initWithExceptionMatcher:(id)exceptionMatcher;

@end


FOUNDATION_EXPORT id HC_throwsException(id exceptionMatcher);

/**
 throwsException(exceptionMatcher) -
 Matches if object is a block which, when executed, throws an exception satisfying a given matcher.

 @param exceptionMatcher  The matcher to satisfy when passed the exception.

 Example:
 @li @ref throwsException(instanceOf([NSException class]))

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_throwsException instead.)

 @ingroup object_matchers
*/
#ifdef HC_SHORTHAND
    #define throwsException HC_throwsException
#endif
