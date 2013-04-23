
@class BuildTestsAction;
@class RunTestsAction;

// Interfaces exposed for testing.
@interface TestAction (Internal)

- (NSArray *)onlyList;
- (BuildTestsAction *)buildTestsAction;
- (RunTestsAction *)runTestsAction;

@end
