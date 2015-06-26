struct __va_list_tag {
  unsigned int _field1;
  unsigned int _field2;
  void *_field3;
  void *_field4;
};

@interface XCTestObserver : NSObject
{
}

+ (void)initialize;
+ (void)suspendObservation;
+ (void)resumeObservation;
+ (void)tearDownTestObservers;
+ (void)setUpTestObservers;
+ (void)removeTestObserverClass:(Class)arg1;
+ (void)addTestObserverClass:(Class)arg1;
- (void)testCaseDidFail:(id)arg1 withDescription:(id)arg2 inFile:(id)arg3 atLine:(NSUInteger)arg4;
- (void)testCaseDidStop:(id)arg1;
- (void)testCaseDidStart:(id)arg1;
- (void)testSuiteDidStop:(id)arg1;
- (void)testSuiteDidStart:(id)arg1;
- (void)_testCaseDidFail:(id)arg1;
- (void)_testCaseDidStop:(id)arg1;
- (void)_testCaseDidStart:(id)arg1;
- (void)_testSuiteDidStop:(id)arg1;
- (void)_testSuiteDidStart:(id)arg1;
- (void)stopObserving;
- (void)startObserving;

@end

@interface XCTest : NSObject
{
}

- (id)run;
- (void)tearDown;
- (void)setUp;
- (void)performTest:(id)arg1;
- (id)name;
- (Class)testRunClass;
- (NSUInteger)testCaseCount;
- (BOOL)isEmpty;
- (void)removeTestsWithNames:(id)arg1;

@end

@interface XCTestRun : NSObject
{
  double startDate;
  double stopDate;
  XCTest *test;
}

+ (id)testRunWithTest:(id)arg1;
- (id)description;
- (BOOL)hasSucceeded;
- (NSUInteger)testCaseCount;
- (NSUInteger)unexpectedExceptionCount;
- (NSUInteger)failureCount;
- (NSUInteger)totalFailureCount;
- (void)stop;
- (void)start;
- (id)stopDate;
- (id)startDate;
- (double)testDuration;
- (double)totalDuration;
- (id)test;
- (void)dealloc;
- (id)initWithTest:(id)arg1;

@end

@interface XCTestCaseRun : XCTestRun
{
  NSUInteger failureCount;
  NSUInteger unexpectedExceptionCount;
}

- (void)recordFailureInTest:(id)arg1 withDescription:(id)arg2 inFile:(id)arg3 atLine:(NSUInteger)arg4 expected:(BOOL)arg5;
- (NSUInteger)unexpectedExceptionCount;
- (NSUInteger)failureCount;
- (void)stop;
- (void)start;

@end

@interface XCTestSuite : XCTest
{
  NSString *name;
  NSMutableArray *tests;
}

+ (id)defaultTestSuite;
+ (id)allTests;
+ (id)structuredTests;
+ (id)testSuiteForTestCaseClass:(Class)arg1;
+ (id)testSuiteForTestCaseWithName:(id)arg1;
+ (id)testSuiteForBundlePath:(id)arg1;
+ (id)suiteForBundleCache;
+ (void)invalidateCache;
+ (id)_suiteForBundleCache;
+ (id)emptyTestSuiteNamedFromPath:(id)arg1;
+ (id)testSuiteWithName:(id)arg1;
- (void)performTest:(id)arg1;
- (Class)testRunClass;
- (NSUInteger)testCaseCount;
- (id)tests;
- (void)addTestsEnumeratedBy:(id)arg1;
- (void)addTest:(id)arg1;
- (id)description;
- (id)name;
- (void)dealloc;
- (id)initWithName:(id)arg1;
- (void)removeTestsWithNames:(id)arg1;
- (void)setName:(id)arg1;

@end

@interface XCTestCaseSuite : XCTestSuite
{
    Class testCaseClass;
}

+ (id)emptyTestSuiteForTestCaseClass:(Class)arg1;
- (void)tearDown;
- (void)setUp;
- (id)initWithTestCaseClass:(Class)arg1;

@end

@interface XCTestCase : XCTest
{
    NSInvocation *_invocation;
    XCTestCaseRun *_testCaseRun;
    BOOL _continueAfterFailure;
}

+ (id)testInvocations;
+ (BOOL)isInheritingTestCases;
+ (id)testCaseWithSelector:(SEL)arg1;
+ (id)testCaseWithInvocation:(id)arg1;
+ (void)tearDown;
+ (void)setUp;
+ (id)defaultTestSuite;
+ (id)xct_allTestMethodInvocations;
+ (id)xct_testMethodInvocations;
+ (id)xct_allSubclasses;
@property BOOL continueAfterFailure; // @synthesize continueAfterFailure=_continueAfterFailure;
@property(retain) XCTestCaseRun *testCaseRun; // @synthesize testCaseRun=_testCaseRun;
- (NSUInteger)numberOfTestIterationsForTestWithSelector:(SEL)arg1;
- (void)afterTestIteration:(NSUInteger)arg1 selector:(SEL)arg2;
- (void)beforeTestIteration:(NSUInteger)arg1 selector:(SEL)arg2;
- (void)tearDownTestWithSelector:(SEL)arg1;
- (void)setUpTestWithSelector:(SEL)arg1;
- (void)performTest:(id)arg1;
- (void)invokeTest;
- (Class)testRunClass;
- (void)_recordUnexpectedFailureWithDescription:(id)arg1 exception:(id)arg2;
- (void)recordFailureWithDescription:(id)arg1 inFile:(id)arg2 atLine:(NSUInteger)arg3 expected:(BOOL)arg4;
- (void)setInvocation:(id)arg1;
- (id)invocation;
- (void)dealloc;
- (id)description;
- (id)name;
- (NSUInteger)testCaseCount;
- (SEL)selector;
- (id)initWithSelector:(SEL)arg1;
- (id)initWithInvocation:(id)arg1;
- (id)init;

@end

@interface XCTestLog : XCTestObserver
{
}

- (void)testCaseDidFail:(id)arg1 withDescription:(id)arg2 inFile:(id)arg3 atLine:(NSUInteger)arg4;
- (void)testSuiteDidStop:(id)arg1;
- (void)testSuiteDidStart:(id)arg1;
- (void)testCaseDidStop:(id)arg1;
- (void)testCaseDidStart:(id)arg1;
- (void)testLogWithFormat:(id)arg1 arguments:(struct __va_list_tag [1])arg2;
- (void)testLogWithFormat:(id)arg1;
- (id)logFileHandle;

@end

@interface XCTestSuiteRun : XCTestRun
{
    NSMutableArray *runs;
}

- (double)testDuration;
- (NSUInteger)unexpectedExceptionCount;
- (NSUInteger)failureCount;
- (void)addTestRun:(id)arg1;
- (id)testRuns;
- (void)stop;
- (void)start;
- (void)dealloc;
- (id)initWithTest:(id)arg1;

@end

@interface XCTestProbe : NSObject
{
}

+ (void)load;
+ (void)initialize;
+ (void)_applicationFinishedLaunching:(id)arg1;
+ (void)runTests:(id)arg1;
+ (void)resumeAppSleep:(id)arg1;
+ (id)suspendAppSleep;
+ (void)runTestsAtUnitPath:(id)arg1 scope:(id)arg2;
+ (id)specifiedTestSuite;
+ (id)multiTestSuiteForScope:(id)arg1 inverse:(BOOL)arg2;
+ (id)testCaseNamesForScopeNames:(id)arg1;
+ (id)testedBundlePath;
+ (BOOL)isTesting;
+ (BOOL)isInverseTestScope;
+ (id)testScope;
+ (BOOL)isLoadedFromTool;
+ (BOOL)isProcessActingAsTestRig;
+ (BOOL)isLoadedFromApplication;

@end

@interface NSFileManager (XCTestAdditions)
- (BOOL)xct_fileExistsAtPathOrLink:(id)arg1;
@end

@interface NSValue (XCTestAdditions)
- (id)xct_contentDescription;
@end
