//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCBaseMatcher.h>


@interface HCIsDictionaryContaining : HCBaseMatcher

+ (instancetype)isDictionaryContainingKey:(id <HCMatcher>)keyMatcher
                                    value:(id <HCMatcher>)valueMatcher;

- (instancetype)initWithKeyMatcher:(id <HCMatcher>)keyMatcher
                      valueMatcher:(id <HCMatcher>)valueMatcher;

@end


FOUNDATION_EXPORT id HC_hasEntry(id keyMatch, id valueMatch);

/**
 hasEntry(keyMatcher, valueMatcher) -
 Matches if dictionary contains key-value entry satisfying a given pair of matchers.

 @param keyMatcher    The matcher to satisfy for the key, or an expected value for @ref equalTo matching.
 @param valueMatcher  The matcher to satisfy for the value, or an expected value for @ref equalTo matching.

 This matcher iterates the evaluated dictionary, searching for any key-value entry that satisfies
 @a keyMatcher and @a valueMatcher. If a matching entry is found, @c hasEntry is satisfied.

 Any argument that is not a matcher is implicitly wrapped in an @ref equalTo matcher to check for
 equality.

 Examples:
 @li @ref hasEntry(@ref equalTo(@"foo"), equalTo(@"bar"))
 @li @ref hasEntry(@"foo", @"bar")

 (In the event of a name clash, don't \#define @c HC_SHORTHAND and use the synonym
 @c HC_hasEntry instead.)

 @ingroup collection_matchers
 */
#ifdef HC_SHORTHAND
    #define hasEntry HC_hasEntry
#endif
