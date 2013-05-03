#import "JUnitReporter.h"

#import <sys/ioctl.h>
#import <unistd.h>

#import <QuartzCore/QuartzCore.h>

#import "Action.h"
#import "NSFileHandle+Print.h"
#import "RunTestsAction.h"

@implementation JUnitReporter {
    NSString *_currentSuiteName;
    NSMutableString *_currentSuiteXML;
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

- (BOOL)openWithStandardOutput:(NSFileHandle *)standardOutput error:(NSString **)error
{
    if ([self.outputPath isEqualToString:@"-"]) {
        _outputHandle = [standardOutput retain];
        return YES;
    } else {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        BOOL isDirectory = NO;
        BOOL exists = [fileManager fileExistsAtPath:self.outputPath isDirectory:&isDirectory];
        
        if (exists && !isDirectory) {
            *error = [NSString stringWithFormat:@"Output path is not a directory '%@'.", self.outputPath];
            return NO;
        } else if (!exists) {
            NSError *createDirError = nil;
            [fileManager createDirectoryAtPath:self.outputPath withIntermediateDirectories:YES attributes:nil error:&createDirError];
            if (createDirError) {
                *error = [NSString stringWithFormat:@"Failed to create output directory '%@'.", self.outputPath];
                return NO;
            }
        }
        
        return YES;
    }
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
}

- (void)endOcunit:(NSDictionary *)event {
}

- (void)beginTestSuite:(NSDictionary *)event {
    _currentSuiteName = event[@"suite"];
    _currentSuiteXML = [NSMutableString new];
}

- (void)endTestSuite:(NSDictionary *)event {
    if (!_currentSuiteName) {
        return;
    }
    
    NSNumber *testCaseCount = event[@"testCaseCount"];
    NSNumber *totalDuration = event[@"totalDuration"];
    NSNumber *totalFailureCount = event[@"totalFailureCount"];
    NSNumber *unexpectedExceptionCount = event[@"unexpectedExceptionCount"];
    
    NSString *header = [NSString stringWithFormat:
                        @"<?xml version='1.0' encoding='UTF-8' ?>\n"
                        @"<testsuite name='%@' tests='%i' errors='%i' failures='%i' time='%f'>\n",
                        _currentSuiteName, [testCaseCount intValue], [unexpectedExceptionCount intValue], [totalFailureCount intValue], [totalDuration floatValue]];
    NSString *footer = @"</testsuite>\n";
    
    NSString *fullString = [NSString stringWithFormat:@"%@%@%@", header, _currentSuiteXML, footer];
    NSString *testSuiteFileName = [NSString stringWithFormat:@"TEST-%@.xml", _currentSuiteName];
    
    if (_outputHandle) {
        [_outputHandle writeData:[fullString dataUsingEncoding:NSUTF8StringEncoding]];
    } else {
        NSString *filePath = [self.outputPath stringByAppendingPathComponent:testSuiteFileName];
        [fullString writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    
    _currentSuiteName = nil;
    _currentSuiteXML = nil;
}

- (void)beginTest:(NSDictionary *)event {
}

- (void)endTest:(NSDictionary *)event {
    NSString *testName = event[@"test"];
    NSNumber *duration = event[@"totalDuration"];
    
    NSString *trimmedTestName = [testName substringWithRange:NSMakeRange(2, testName.length - 3)];
    NSArray *splitTestName = [trimmedTestName componentsSeparatedByString:@" "];
    
    NSString *className = splitTestName[0];
    NSString *methodName = splitTestName[1];
    
    NSString *xmlJUnitOutput = [NSString stringWithFormat:@"<testcase classname='%@' name='%@' time='%f' />\n", className, methodName, [duration floatValue]];
    [_currentSuiteXML appendString:xmlJUnitOutput];
}

- (void)testOutput:(NSDictionary *)event {
}

- (void)message:(NSDictionary *)event {
}

@end
