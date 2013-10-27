//
// Licensed under the terms in License.txt
//
// Copyright 2010 Allen Ding. All rights reserved.
//

#import "KiwiConfiguration.h"
#import "KWBlock.h"
#import "KWVerifying.h"
#import "KWExpectationType.h"
#import "KWExampleNode.h"
#import "KWExampleNodeVisitor.h"
#import "KWReporting.h"
#import "KWExampleDelegate.h"

@class KWCallSite;
@class KWExampleSuite;
@class KWContextNode;
@class KWSpec;
@class KWMatcherFactory;

@interface KWExample : NSObject <KWExampleNodeVisitor, KWReporting>

@property (nonatomic, strong, readonly) NSMutableArray *lastInContexts;
@property (nonatomic, weak) KWExampleSuite *suite;
@property (nonatomic, strong) id<KWVerifying> unresolvedVerifier;


- (id)initWithExampleNode:(id<KWExampleNode>)node;

#pragma mark - Adding Verifiers

- (id)addVerifier:(id<KWVerifying>)aVerifier;
- (id)addExistVerifierWithExpectationType:(KWExpectationType)anExpectationType callSite:(KWCallSite *)aCallSite;
- (id)addMatchVerifierWithExpectationType:(KWExpectationType)anExpectationType callSite:(KWCallSite *)aCallSite;
- (id)addAsyncVerifierWithExpectationType:(KWExpectationType)anExpectationType callSite:(KWCallSite *)aCallSite timeout:(NSInteger)timeout shouldWait:(BOOL)shouldWait;

#pragma mark - Report failure

- (void)reportFailure:(KWFailure *)failure;

#pragma mark - Running

- (void)runWithDelegate:(id<KWExampleDelegate>)delegate;

#pragma mark - Anonymous It Node Descriptions

- (NSString *)generateDescriptionForAnonymousItNode;

#pragma mark - Checking if last in context

- (BOOL)isLastInContext:(KWContextNode *)context;

#pragma mark - Full description with context

- (NSString *)descriptionWithContext;

@end

#pragma mark - Building Example Groups

void describe(NSString *aDescription, void (^block)(void));
void context(NSString *aDescription, void (^block)(void));
void registerMatchers(NSString *aNamespacePrefix);
void beforeAll(void (^block)(void));
void afterAll(void (^block)(void));
void beforeEach(void (^block)(void));
void afterEach(void (^block)(void));
void it(NSString *aDescription, void (^block)(void));
void specify(void (^block)(void));
void pending_(NSString *aDescription, void (^block)(void));

void describeWithCallSite(KWCallSite *aCallSite, NSString *aDescription, void (^block)(void));
void contextWithCallSite(KWCallSite *aCallSite, NSString *aDescription, void (^block)(void));
void registerMatchersWithCallSite(KWCallSite *aCallSite, NSString *aNamespacePrefix);
void beforeAllWithCallSite(KWCallSite *aCallSite, void (^block)(void));
void afterAllWithCallSite(KWCallSite *aCallSite, void (^block)(void));
void beforeEachWithCallSite(KWCallSite *aCallSite, void (^block)(void));
void afterEachWithCallSite(KWCallSite *aCallSite, void (^block)(void));
void itWithCallSite(KWCallSite *aCallSite, NSString *aDescription, void (^block)(void));
void pendingWithCallSite(KWCallSite *aCallSite, NSString *aDescription, void (^block)(void));

#define PRAGMA(x) _Pragma (#x)
#define PENDING(x) PRAGMA(message ( "Pending: " #x ))

#define pending(title, args...) \
PENDING(title) \
pending_(title, ## args)
#define xit(title, args...) \
PENDING(title) \
pending_(title, ## args)
