//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCBaseMatcher.h>


@interface HCIsAnything : HCBaseMatcher
{
    NSString *description;
}

+ (instancetype)isAnything;
+ (instancetype)isAnythingWithDescription:(NSString *)aDescription;

- (instancetype)init;
- (instancetype)initWithDescription:(NSString *)aDescription;

@end


FOUNDATION_EXPORT id HC_anything(void);

/**
 Matches anything.

 This matcher always evaluates to @c YES. Specify this in composite matchers when the value of a
 particular element is unimportant.

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_anything instead.)

 @ingroup logical_matchers
 */
#ifdef HC_SHORTHAND
    #define anything() HC_anything()
#endif


FOUNDATION_EXPORT id HC_anythingWithDescription(NSString *aDescription);

/**
 anythingWithDescription(description) -
 Matches anything.

 @param description  A string used to describe this matcher.

 This matcher always evaluates to @c YES. Specify this in collection matchers when the value of a
 particular element in a collection is unimportant.

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_anything instead.)

 @ingroup logical_matchers
 */
#ifdef HC_SHORTHAND
    #define anythingWithDescription HC_anythingWithDescription
#endif
