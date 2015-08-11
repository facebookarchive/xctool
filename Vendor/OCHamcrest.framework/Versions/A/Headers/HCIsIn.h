//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCBaseMatcher.h>


@interface HCIsIn : HCBaseMatcher

+ (instancetype)isInCollection:(id)collection;
- (instancetype)initWithCollection:(id)collection;

@end


FOUNDATION_EXPORT id HC_isIn(id aCollection);

/**
 isIn(aCollection) -
 Matches if evaluated object is present in a given collection.

 @param aCollection  The collection to search.

 This matcher invokes @c -containsObject: on @a aCollection to determine if the evaluated object
 is an element of the collection.

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_isIn instead.)

 @ingroup collection_matchers
 */
#ifdef HC_SHORTHAND
    #define isIn HC_isIn
#endif
