//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt
//  Contribution by Todd Farrell

#import <OCHamcrest/HCBaseMatcher.h>


@interface HCConformsToProtocol : HCBaseMatcher

+ (instancetype)conformsTo:(Protocol *)protocol;
- (instancetype)initWithProtocol:(Protocol *)protocol;

@end


FOUNDATION_EXPORT id HC_conformsTo(Protocol *aProtocol);

/**
 conformsTo(aProtocol) -
 Matches if object conforms to a given protocol.

 @param aProtocol  The protocol to compare against as the expected protocol.

 This matcher checks whether the evaluated object conforms to @a aProtocol.

 Example:
 @li @ref conformsTo(\@protocol(NSObject))

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_conformsTo instead.)

 @ingroup object_matchers
 */
#ifdef HC_SHORTHAND
    #define conformsTo HC_conformsTo
#endif
