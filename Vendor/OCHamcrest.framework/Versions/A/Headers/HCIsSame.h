//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCBaseMatcher.h>


@interface HCIsSame : HCBaseMatcher

+ (instancetype)isSameAs:(id)object;
- (instancetype)initSameAs:(id)object;

@end


FOUNDATION_EXPORT id HC_sameInstance(id object);

/**
 sameInstance(anObject) -
 Matches if evaluated object is the same instance as a given object.

 @param anObject  The object to compare against as the expected value.

 This matcher compares the address of the evaluated object to determine if it is the same object
 as @a anObject.

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_sameInstance instead.)

 @ingroup object_matchers
 */
#ifdef HC_SHORTHAND
    #define sameInstance HC_sameInstance
#endif
