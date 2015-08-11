//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCBaseMatcher.h>


@interface HCIsDictionaryContainingKey : HCBaseMatcher

+ (instancetype)isDictionaryContainingKey:(id <HCMatcher>)keyMatcher;
- (instancetype)initWithKeyMatcher:(id <HCMatcher>)keyMatcher;

@end


FOUNDATION_EXPORT id HC_hasKey(id keyMatch);

/**
 hasKey(keyMatcher) -
 Matches if dictionary contains an entry whose key satisfies a given matcher.

 @param keyMatcher  The matcher to satisfy for the key, or an expected value for @ref equalTo matching.

 This matcher iterates the evaluated dictionary, searching for any key-value entry whose key
 satisfies the given matcher. If a matching entry is found, @c hasKey is satisfied.

 Any argument that is not a matcher is implicitly wrapped in an @ref equalTo matcher to check for
 equality.

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_hasKey instead.)

 Examples:
 @li @ref hasEntry(equalTo(@"foo"))
 @li @ref hasEntry(@"foo")

 @ingroup collection_matchers
 */
#ifdef HC_SHORTHAND
    #define hasKey HC_hasKey
#endif
