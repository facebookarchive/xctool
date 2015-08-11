//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <OCHamcrest/HCBaseMatcher.h>


@interface HCSubstringMatcher : HCBaseMatcher

@property (readonly, nonatomic, copy) NSString *substring;

- (instancetype)initWithSubstring:(NSString *)aString;

@end
