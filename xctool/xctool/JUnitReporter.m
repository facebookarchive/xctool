#import "JUnitReporter.h"


#pragma mark Private Interface
@interface JUnitReporter ()

@property (nonatomic, retain) NSMutableArray *testResults;
@property (nonatomic, retain) NSDateFormatter *formatter;
@property (nonatomic, retain) NSRegularExpression *regex;

- (void)writeTestSuite:(NSDictionary *)event;
- (void)write:(NSString *)string;
- (NSString *)xmlEscape:(NSString *)string;

@end

#pragma mark Implementation
@implementation JUnitReporter

#pragma mark Memory Management
- (id)init {
    if (self = [super init]) {
        _formatter = [[NSDateFormatter alloc] init];
        [_formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZ"];
        self.regex = [NSRegularExpression regularExpressionWithPattern:@"^-\\[\\w+ (\\w+)\\]$"
                                                               options:0
                                                                 error:nil];
    }
    return self;
}

- (void)dealloc {
    self.testResults = nil;
    self.formatter = nil;
    self.regex = nil;
    [super dealloc];
}

#pragma mark Reporter
- (BOOL)openWithStandardOutput:(NSFileHandle *)standardOutput error:(NSString **)error {
    BOOL success;
    if ([self.outputPath isEqualToString:@"-"]) {
        _outputHandle = [standardOutput retain];
        success = YES;
    } else {
        BOOL isDir;
        success = ([[NSFileManager defaultManager] fileExistsAtPath:self.outputPath isDirectory:&isDir] && isDir &&
                [[NSFileManager defaultManager] isWritableFileAtPath:self.outputPath]);
    }
    return success;
}

- (void)beginTestSuite:(NSDictionary *)event {
    self.testResults = [NSMutableArray array];
}

- (void)endTest:(NSDictionary *)event {
    [self.testResults addObject:event];
}

- (void)endTestSuite:(NSDictionary *)event {
    if (self.testResults) { // Prevents nested suites
        if (_outputHandle) { // To stdout
            [self writeTestSuite:event];
        } else { // To file
            NSString *testSuitePath = [[self.outputPath stringByAppendingPathComponent:event[kReporter_EndTestSuite_SuiteKey]] stringByAppendingPathExtension:@"xml"];
            if ([[NSFileManager defaultManager] createFileAtPath:testSuitePath contents:nil attributes:nil]) {
                _outputHandle = [[NSFileHandle fileHandleForWritingAtPath:testSuitePath] retain];
                if (_outputHandle) {
                    [self writeTestSuite:event];
                    [self close];
                } else {
                    NSLog(@"Error opening file for suite: %@", testSuitePath);
                }
            } else {
                NSLog(@"Error creating file for suite: %@", testSuitePath);
            }
        }
        self.testResults = nil;
    }
}

- (void)close {
    if (_outputHandle) {
        [super close];
        [_outputHandle release];
        _outputHandle = nil;
    }
}

#pragma mark Private Methods
- (void)writeTestSuite:(NSDictionary *)event {
    NSString *suiteName = [self xmlEscape:event[kReporter_EndTestSuite_SuiteKey]];
    [self write:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"];
    [self write:[NSString stringWithFormat:@"<testsuite errors=\"%d\" failures=\"%d\" hostname=\"%@\" name=\"%@\" tests=\"%d\" time=\"%f\" timestamp=\"%@\">\n",
                 [event[kReporter_EndTestSuite_UnexpectedExceptionCountKey] intValue],
                 [event[kReporter_EndTestSuite_TotalFailureCountKey] intValue],
                 @"", suiteName,
                 [event[kReporter_EndTestSuite_TestCaseCountKey] intValue],
                 [event[kReporter_EndTestSuite_TotalDurationKey] floatValue],
                 [self.formatter stringFromDate:[NSDate date]]]];
    for (NSDictionary *testResult in self.testResults) {
        NSString *testName = testResult[kReporter_EndTest_TestKey];
        NSTextCheckingResult *match = [self.regex firstMatchInString:testName
                                                             options:0
                                                               range:NSMakeRange(0, [testName length])];
        if (match) {
            NSRange firstGroupRange = [match rangeAtIndex:1];
            if (firstGroupRange.location != NSNotFound) {
                testName = [testName substringWithRange:firstGroupRange];
            }
        }
        [self write:[NSString stringWithFormat:@"\t<testcase classname=\"%@\" name=\"%@\" time=\"%f\">\n", suiteName, [self xmlEscape:testName], [testResult[kReporter_EndTest_TotalDurationKey] floatValue]]];
        if (![testResult[kReporter_EndTest_SucceededKey] boolValue]) {
            NSDictionary *exception = testResult[kReporter_EndTest_ExceptionKey];
            [self write:[NSString stringWithFormat:@"\t\t<failure message=\"%@\" type=\"Failure\">%@:%d</failure>\n",
                         [self xmlEscape:exception[kReporter_EndTest_Exception_ReasonKey]],
                         [self xmlEscape:exception[kReporter_EndTest_Exception_FilePathInProjectKey]],
                         [exception[kReporter_EndTest_Exception_LineNumberKey] intValue]]];
        }
        NSString *output = testResult[kReporter_EndTest_OutputKey];
        if (output && output.length > 0) {
            [self write:[NSString stringWithFormat:@"\t\t<system-out>%@</system-out>\n", [self xmlEscape:output]]];
        }
        [self write:@"\t</testcase>\n"];
    }
    [self write:@"</testsuite>\n"];
}

- (void)write:(NSString *)string {
    [self.outputHandle writeData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

- (NSString *)xmlEscape:(NSString *)string {
    return [[[[[string stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"]
        stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"]
       stringByReplacingOccurrencesOfString:@"'" withString:@"&#39;"]
      stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"]
     stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
}

@end
