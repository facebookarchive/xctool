//
// Licensed under the terms in License.txt
//
// Copyright 2010 Allen Ding. All rights reserved.
//

#import "KWRaiseMatcher.h"
#import "KWFormatter.h"

@interface KWRaiseMatcher()

#pragma mark - Properties

@property (nonatomic, assign) SEL selector;
@property (nonatomic, strong) NSException *exception;
@property (nonatomic, strong) NSException *actualException;

@end

@implementation KWRaiseMatcher


#pragma mark - Getting Matcher Strings

+ (NSArray *)matcherStrings {
    return @[@"raiseWhenSent:",
                                     @"raiseWithName:whenSent:",
                                     @"raiseWithReason:whenSent:",
                                     @"raiseWithName:reason:whenSent:"];
}

#pragma mark - Matching

- (BOOL)evaluate {
    @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.subject performSelector:self.selector];
#pragma clang diagnostic pop
    } @catch (NSException *anException) {
        self.actualException = anException;

        if ([self.exception name] != nil && ![[self.exception name] isEqualToString:[anException name]])
            return NO;

        if ([self.exception reason] != nil && ![[self.exception reason] isEqualToString:[anException reason]])
            return NO;

        return YES;
    }

    return NO;
}

#pragma mark - Getting Failure Messages

+ (NSString *)exceptionPhraseWithException:(NSException *)anException {
    if (anException == nil)
        return @"nothing";

    NSString *namePhrase = nil;

    if ([anException name] == nil)
        namePhrase = @"exception";
    else
        namePhrase = [anException name];

    if ([anException reason] == nil)
        return namePhrase;

    return [NSString stringWithFormat:@"%@ \"%@\"", namePhrase, [anException reason]];
}

- (NSString *)failureMessageForShould {
    return [NSString stringWithFormat:@"expected %@, but %@ raised",
                                      [[self class] exceptionPhraseWithException:self.exception],
                                      [[self class] exceptionPhraseWithException:self.actualException]];
}

- (NSString *)failureMessageForShouldNot {
    return [NSString stringWithFormat:@"expected %@ not to be raised",
                                      [[self class] exceptionPhraseWithException:self.actualException]];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"raise %@ when sent %@", [[self class] exceptionPhraseWithException:self.exception], NSStringFromSelector(self.selector)];
}

#pragma mark - Configuring Matchers

- (void)raiseWhenSent:(SEL)aSelector {
    [self raiseWithName:nil reason:nil whenSent:aSelector];
}

- (void)raiseWithName:(NSString *)aName whenSent:(SEL)aSelector {
    [self raiseWithName:aName reason:nil whenSent:aSelector];
}

- (void)raiseWithReason:(NSString *)aReason whenSent:(SEL)aSelector {
    [self raiseWithName:nil reason:aReason whenSent:aSelector];
}

- (void)raiseWithName:(NSString *)aName reason:(NSString *)aReason whenSent:(SEL)aSelector {
    self.selector = aSelector;
    self.exception = [NSException exceptionWithName:aName reason:aReason userInfo:nil];
}

@end
