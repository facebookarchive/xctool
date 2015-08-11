//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCClassMatcher.h>


@interface HCIsTypeOf : HCClassMatcher

+ (id)isTypeOf:(Class)type;

@end


FOUNDATION_EXPORT id HC_isA(Class aClass);

/**
 isA(aClass) -
 Matches if object is an instance of a given class (but not of a subclass).

 @param aClass  The class to compare against as the expected class.

 This matcher checks whether the evaluated object is an instance of @a aClass.

 Example:
 @li @ref isA([Foo class])

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_isA instead.)

 @ingroup object_matchers
 */
#ifdef HC_SHORTHAND
    #define isA HC_isA
#endif
