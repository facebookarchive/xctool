//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCBaseMatcher.h>


@interface HCIsEqualIgnoringCase : HCBaseMatcher

+ (instancetype)isEqualIgnoringCase:(NSString *)string;
- (instancetype)initWithString:(NSString *)string;

@end


FOUNDATION_EXPORT id HC_equalToIgnoringCase(NSString *aString);

/**
 equalToIgnoringCase(string) -
 Matches if object is a string equal to a given string, ignoring case differences.

 @param aString  The string to compare against as the expected value. This value must not be @c nil.

 This matcher first checks whether the evaluated object is a string. If so, it compares it with
 @a aString, ignoring differences of case.

 Example:

 @par
 @ref equalToIgnoringCase(@"hello world")

 will match "heLLo WorlD".

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_equalToIgnoringCase instead.)

 @ingroup text_matchers
 */
#ifdef HC_SHORTHAND
    #define equalToIgnoringCase HC_equalToIgnoringCase
#endif
