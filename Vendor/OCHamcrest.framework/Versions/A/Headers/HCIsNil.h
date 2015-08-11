//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCBaseMatcher.h>


@interface HCIsNil : HCBaseMatcher

+ (id)isNil;

@end


FOUNDATION_EXPORT id HC_nilValue(void);

/**
 Matches if object is @c nil.

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_nilValue instead.)

 @ingroup object_matchers
 */
#ifdef HC_SHORTHAND
    #define nilValue() HC_nilValue()
#endif


FOUNDATION_EXPORT id HC_notNilValue(void);

/**
 Matches if object is not @c nil.

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_notNilValue instead.)

 @ingroup object_matchers
 */
#ifdef HC_SHORTHAND
    #define notNilValue() HC_notNilValue()
#endif
