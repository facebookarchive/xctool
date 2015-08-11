//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <Foundation/Foundation.h>
#import <OCHamcrest/HCMatcher.h>

#define HC_ABSTRACT_METHOD [self subclassResponsibility:_cmd]


/**
 Base class for all HCMatcher implementations.

 Simple matchers can just subclass HCBaseMatcher and implement @c -matches: and @c -describeTo:. But
 if the matching algorithm has several "no match" paths, consider subclassing HCDiagnosingMatcher
 instead.

 @ingroup core
 */
@interface HCBaseMatcher : NSObject <HCMatcher, NSCopying>

/// Raises exception that command (a pseudo-abstract method) is not implemented.
- (void)subclassResponsibility:(SEL)command;

@end
