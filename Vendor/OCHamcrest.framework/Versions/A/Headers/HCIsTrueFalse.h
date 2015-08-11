//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCBaseMatcher.h>


@interface HCIsTrue : HCBaseMatcher
@end

@interface HCIsFalse : HCBaseMatcher
@end


FOUNDATION_EXPORT id HC_isTrue(void);

/**
 isTrue() -
 Matches if object is equal to @c NSNumber with non-zero value.

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_isTrue instead.)

 @ingroup primitive_number_matchers
 */
#ifdef HC_SHORTHAND
    #define isTrue() HC_isTrue()
#endif


FOUNDATION_EXPORT id HC_isFalse(void);

/**
 isFalse() -
 Matches if object is equal to @c NSNumber with zero value.

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_isFalse instead.)

 @ingroup primitive_number_matchers
*/
#ifdef HC_SHORTHAND
    #define isFalse() HC_isFalse()
#endif
