//
// Licensed under the terms in License.txt
//
// Copyright 2010 Allen Ding. All rights reserved.
//

#import "KWBeZeroMatcher.h"
#import "KWFormatter.h"
#import "KWValue.h"

@implementation KWBeZeroMatcher

#pragma mark - Getting Matcher Strings

+ (NSArray *)matcherStrings {
    return @[@"beZero"];
}

#pragma mark - Matching

- (BOOL)evaluate {
    if (![self.subject respondsToSelector:@selector(boolValue)])
        [NSException raise:@"KWMatcherException" format:@"subject does not respond to -numberValue"];

    return [[self.subject numberValue] isEqualToNumber:@0];
}

#pragma mark - Getting Failure Messages

- (NSString *)failureMessageForShould {
    return [NSString stringWithFormat:@"expected subject to be zero, got %@",
                                      [KWFormatter formatObject:self.subject]];
}

- (NSString *)failureMessageForShouldNot {
    return [NSString stringWithFormat:@"expected subject not to be zero"];
}

#pragma mark - Configuring Matchers

- (void)beZero {
}

@end
