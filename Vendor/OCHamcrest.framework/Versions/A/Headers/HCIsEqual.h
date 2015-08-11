//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCBaseMatcher.h>


@interface HCIsEqual : HCBaseMatcher

+ (instancetype)isEqualTo:(id)object;
- (instancetype)initEqualTo:(id)object;

@end


FOUNDATION_EXPORT id HC_equalTo(id object);

/**
 equalTo(anObject) -
 Matches if object is equal to a given object.

 @param anObject  The object to compare against as the expected value.

 This matcher compares the evaluated object to @a anObject for equality, as determined by the
 @c -isEqual: method.

 If @a anObject is @c nil, the matcher will successfully match @c nil.

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_equalTo instead.)

 @ingroup object_matchers
 */
#ifdef HC_SHORTHAND
    #define equalTo HC_equalTo
#endif
