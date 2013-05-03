#import "JUnitReporter.h"

#import <sys/ioctl.h>
#import <unistd.h>

#import <QuartzCore/QuartzCore.h>

#import "Action.h"
#import "NSFileHandle+Print.h"
#import "RunTestsAction.h"

@implementation JUnitReporter {
    NSMutableArray *_suites;
    NSMutableDictionary *_currentSuite;
    int _totalTests;
    int _totalFailures;
    int _totalErrors;
    float _totalTime;
}

- (id)init
{
  if (self = [super init]) {
  }
  return self;
}

- (void)dealloc
{
  [super dealloc];
}

- (void)beginAction:(NSDictionary *)event {}
- (void)endAction:(NSDictionary *)event {}
- (void)beginBuildTarget:(NSDictionary *)event {}
- (void)endBuildTarget:(NSDictionary *)event {}
- (void)beginBuildCommand:(NSDictionary *)event {}
- (void)endBuildCommand:(NSDictionary *)event {}
- (void)beginXcodebuild:(NSDictionary *)event {}
- (void)endXcodebuild:(NSDictionary *)event {}

- (void)beginOcunit:(NSDictionary *)event {
    _suites = [NSMutableArray new];
}

- (void)endOcunit:(NSDictionary *)event {
    NSMutableString *xml = [NSMutableString new];
    [xml appendString:@"<?xml version='1.0' encoding='UTF-8' ?>\n"];
    
    [xml appendFormat:@"<testsuites name='AllTests' time='%f' tests='%i' failures='%i' errors='%i'>\n", _totalTime, _totalTests, _totalFailures, _totalErrors];
    
    for (NSDictionary *suite in _suites) {
        [xml appendFormat:@"<testsuite name='%@' tests='%i' errors='%i' failures='%i' time='%f'>\n",
         suite[@"name"], [suite[@"testCaseCount"] intValue], [suite[@"unexpectedExceptionCount"] intValue], [suite[@"totalFailureCount"] intValue], [suite[@"totalDuration"] floatValue]];
        
        for (NSDictionary *test in suite[@"tests"]) {
            [xml appendFormat:@"<testcase classname='%@' name='%@' time='%f' />\n", test[@"classname"], test[@"name"], [test[@"time"] floatValue]];
        }
        
        [xml appendString:@"</testsuite>\n"];
    }
    
    [xml appendString:@"</testsuites>\n"];
    
    [_outputHandle writeData:[xml dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)beginTestSuite:(NSDictionary *)event {
    NSString *name = event[@"suite"];
    if (name) {
        _currentSuite = [NSMutableDictionary new];
        _currentSuite[@"name"] = name;
        _currentSuite[@"tests"] = [NSMutableArray new];
        _totalTests = 0;
        _totalTime = 0.0f;
        _totalFailures = 0;
        _totalErrors = 0;
    }
}

- (void)endTestSuite:(NSDictionary *)event {
    if (!_currentSuite) {
        return;
    }
    
    NSNumber *testCaseCount = event[@"testCaseCount"];
    NSNumber *totalDuration = event[@"totalDuration"];
    NSNumber *totalFailureCount = event[@"totalFailureCount"];
    NSNumber *unexpectedExceptionCount = event[@"unexpectedExceptionCount"];
    
    _totalTests += [testCaseCount intValue];
    _totalTime += [totalDuration floatValue];
    _totalFailures += [totalFailureCount intValue];
    _totalErrors += [unexpectedExceptionCount intValue];
    
    _currentSuite[@"testCaseCount"] = testCaseCount;
    _currentSuite[@"totalDuration"] = totalDuration;
    _currentSuite[@"totalFailureCount"] = totalFailureCount;
    _currentSuite[@"unexpectedExceptionCount"] = unexpectedExceptionCount;
    
    [_suites addObject:_currentSuite];
    _currentSuite = nil;
}

- (void)beginTest:(NSDictionary *)event {
}

- (void)endTest:(NSDictionary *)event {
    NSMutableArray *tests = _currentSuite[@"tests"];
    
    NSString *testName = event[@"test"];
    NSNumber *duration = event[@"totalDuration"];
    
    NSString *trimmedTestName = [testName substringWithRange:NSMakeRange(2, testName.length - 3)];
    NSArray *splitTestName = [trimmedTestName componentsSeparatedByString:@" "];
    
    NSString *className = splitTestName[0];
    NSString *methodName = splitTestName[1];
    
    [tests addObject:@{@"classname":className, @"name":methodName, @"time":duration}];
}

- (void)testOutput:(NSDictionary *)event {
}

- (void)message:(NSDictionary *)event {
}

@end
