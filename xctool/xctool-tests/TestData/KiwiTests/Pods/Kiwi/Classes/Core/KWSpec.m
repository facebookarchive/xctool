//
// Licensed under the terms in License.txt
//
// Copyright 2010 Allen Ding. All rights reserved.
//

#import "KWSpec.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "KWCallSite.h"
#import "KWExample.h"
#import "KWExampleSuiteBuilder.h"
#import "KWIntercept.h"
#import "KWObjCUtilities.h"
#import "KWStringUtilities.h"
#import "NSMethodSignature+KiwiAdditions.h"
#import "KWFailure.h"
#import "KWExampleSuite.h"


@interface KWSpec()

@property (nonatomic, strong) KWExample *currentExample;

@end

@implementation KWSpec

/* Methods are only implemented by sub-classes */

+ (NSString *)file { return nil; }

+ (void)buildExampleGroups {}

/* SenTestingKit uses -description, XCTest uses -name when displaying tests
 in test navigator. Use camel case to make method friendly names from example description.
 */

- (NSString *)name {
    return [self description];
}

- (NSString *)description {
    KWExample *currentExample = self.currentExample ? self.currentExample : [[self invocation] kw_example];
    NSString *name = [currentExample descriptionWithContext];
    
    // CamelCase the string
    NSArray *words = [name componentsSeparatedByString:@" "];
    name = @"";
    for (NSString *word in words) {
        if ([word length] < 1)
        {
            continue;
        }
        name = [name stringByAppendingString:[[word substringToIndex:1] uppercaseString]];
        name = [name stringByAppendingString:[word substringFromIndex:1]];
    }
    
    // Replace the commas with underscores to separate the levels of context
    name = [name stringByReplacingOccurrencesOfString:@"," withString:@"_"];
    
    // Strip out characters not legal in function names
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[^a-zA-Z0-9_]*" options:0 error:&error];
    name = [regex stringByReplacingMatchesInString:name options:0 range:NSMakeRange(0, name.length) withTemplate:@""];

    return [NSString stringWithFormat:@"-[%@ %@]", NSStringFromClass([self class]), name];
}

#pragma mark - Getting Invocations

/* Called by the SenTestingKit test suite to get an array of invocations that
   should be run on instances of test cases. */

+ (NSArray *)testInvocations {
    SEL buildExampleGroups = @selector(buildExampleGroups);

    // Only return invocation if the receiver is a concrete spec that has overridden -buildExampleGroups.
    if ([self methodForSelector:buildExampleGroups] == [KWSpec methodForSelector:buildExampleGroups])
        return nil;

    KWExampleSuite *exampleSuite = [[KWExampleSuiteBuilder sharedExampleSuiteBuilder] buildExampleSuite:^{
        [self buildExampleGroups];
    }];
  
    return [exampleSuite invocationsForTestCase];
}

#pragma mark - Running Specs

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

- (void)invokeTest {
    self.currentExample = [[self invocation] kw_example];

    @autoreleasepool {

        @try {
            [self.currentExample runWithDelegate:self];
        } @catch (NSException *exception) {
            if ([self respondsToSelector:@selector(recordFailureWithDescription:inFile:atLine:expected:)]) {
                objc_msgSend(self,
                             @selector(recordFailureWithDescription:inFile:atLine:expected:),
                             [exception description], @"", 0, NO);
            } else {
                objc_msgSend(self, @selector(failWithException:), exception);
            }
        }

        [[self invocation] kw_setExample:nil];

    }
}

#pragma clang diagnostic pop

#pragma mark - KWExampleGroupDelegate methods

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

- (void)example:(KWExample *)example didFailWithFailure:(KWFailure *)failure {
    if ([self respondsToSelector:@selector(recordFailureWithDescription:inFile:atLine:expected:)]) {
        objc_msgSend(self,
                     @selector(recordFailureWithDescription:inFile:atLine:expected:),
                     [[failure exceptionValue] description],
                     failure.callSite.filename,
                     failure.callSite.lineNumber,
                     NO);
    } else {
        objc_msgSend(self, @selector(failWithException:), [failure exceptionValue]);
    }
}

#pragma clang diagnostic pop

#pragma mark - Verification proxies

+ (id)addVerifier:(id<KWVerifying>)aVerifier {
    return [[[KWExampleSuiteBuilder sharedExampleSuiteBuilder] currentExample] addVerifier:aVerifier];
}

+ (id)addExistVerifierWithExpectationType:(KWExpectationType)anExpectationType callSite:(KWCallSite *)aCallSite {
    return [[[KWExampleSuiteBuilder sharedExampleSuiteBuilder] currentExample] addExistVerifierWithExpectationType:anExpectationType callSite:aCallSite];
}

+ (id)addMatchVerifierWithExpectationType:(KWExpectationType)anExpectationType callSite:(KWCallSite *)aCallSite {
    return [[[KWExampleSuiteBuilder sharedExampleSuiteBuilder] currentExample] addMatchVerifierWithExpectationType:anExpectationType callSite:aCallSite];
}

+ (id)addAsyncVerifierWithExpectationType:(KWExpectationType)anExpectationType callSite:(KWCallSite *)aCallSite timeout:(NSInteger)timeout shouldWait:(BOOL)shouldWait {
    return [[[KWExampleSuiteBuilder sharedExampleSuiteBuilder] currentExample] addAsyncVerifierWithExpectationType:anExpectationType callSite:aCallSite timeout:timeout shouldWait: shouldWait];
}

@end
