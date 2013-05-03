//
//  XUnitReporter.m
//  xctool
//
//  Created by Justin Mutter on 2013-05-03.
//  Copyright (c) 2013 Fred Potter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XUnitReporter.h"

@implementation XUnitReporter {

	NSMutableArray *_testResults;
}

- (id)init
{
	if (self = [super init]) {
		NSError *xmlError = nil;
		_testSuitesRootElement = [[NSXMLElement alloc] initWithXMLString:@"<testsuites></testsuites>" error:&xmlError];
		_xmlDocument = [[NSXMLDocument alloc] initWithRootElement:_testSuitesRootElement];
		
	}
	return self;
}

- (void)beginTestSuite:(NSDictionary *)event
{
	_testResults = [NSMutableArray array];
}

- (void)endTestSuite:(NSDictionary *)event
{
	NSString *suiteName = [event valueForKey:kReporter_EndTestSuite_SuiteKey];
	// Skip the wrapper test suites
	if ([suiteName rangeOfString:@"Multiple Selected Tests"].location == NSNotFound &&
		[suiteName rangeOfString:@".octest(Tests)"].location == NSNotFound &&
		[suiteName rangeOfString:@"All tests"].location == NSNotFound) {
		NSInteger tests = [[event valueForKey:kReporter_EndTestSuite_TestCaseCountKey] integerValue];
		NSInteger failures = [[event valueForKey:kReporter_EndTestSuite_TotalFailureCountKey] integerValue];
		NSString *totalTime = [NSString stringWithFormat:@"%f", [[event valueForKey:kReporter_EndTestSuite_TotalDurationKey] doubleValue]];
		
		NSString *host = [[NSHost currentHost] name];
		
		NSError *xmlError = nil;

		NSString *suiteString = [NSString stringWithFormat:@"<testsuite errors=\"0\" failures=\"%ld\" hostname=\"%@\" name=\"%@\" tests=\"%ld\" time=\"%@\"></testsuite>", failures, host, suiteName, tests, totalTime];
		NSXMLElement *suiteElement = [[NSXMLElement alloc] initWithXMLString:suiteString error:&xmlError];
		
		if (xmlError == nil) {
			for (NSDictionary *testResult in _testResults) {
				NSString *testName = [testResult valueForKey:kReporter_EndTest_TestKey];
				// TODO: remove the leading '-[SUITE_NAME' and trailing ']' from the name
				NSRange suiteNameRange = [testName rangeOfString:[NSString stringWithFormat:@"-[%@ ", suiteName]];
				testName = [[[testName stringByReplacingCharactersInRange:suiteNameRange withString:@""] stringByReplacingOccurrencesOfString:@"]" withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
				
				NSString *testTime = [NSString stringWithFormat:@"%f", [[testResult valueForKey:kReporter_EndTest_TotalDurationKey] doubleValue]];

				BOOL passed = [[testResult valueForKey:kReporter_EndTest_SucceededKey] boolValue];
				
				NSString *testString = [NSString stringWithFormat:@"<testcase classname=\"%@\" name=\"%@\" time=\"%@\"></testcase>", suiteName, testName, testTime];
				NSXMLElement *testElement = [[NSXMLElement alloc] initWithXMLString:testString error:&xmlError];
				if (passed == NO) {
					NSDictionary *exception = testResult[kReporter_EndTest_ExceptionKey];
					NSString *message = [NSString stringWithFormat:@"%@: %@", exception[kReporter_EndTest_Exception_NameKey], exception[kReporter_EndTest_Exception_ReasonKey]];
					if ([testResult[kReporter_EndTest_OutputKey] isEqualToString: @""] == NO) {
						message = [NSString stringWithFormat:@"%@ - %@", testResult[kReporter_EndTest_OutputKey], message];
					}
					NSString *location = [NSString stringWithFormat:@"%@:%@", exception[kReporter_EndTest_Exception_FilePathInProjectKey], exception[kReporter_EndTest_Exception_LineNumberKey]];
					
					NSString *failureString = [NSString stringWithFormat:@"<failure message=\"%@\" type=\"Failure\">%@</failure>", message, location];
					NSXMLElement *failureElement = [[NSXMLElement alloc] initWithXMLString:failureString error:&xmlError];
					[testElement addChild:failureElement];
				}
				[suiteElement addChild:testElement];
			}
			[_testSuitesRootElement addChild:suiteElement];
		}
	}
}


- (void)endTest:(NSDictionary *)event
{
	[_testResults addObject:event];
}

- (void)close
{
	[_outputHandle writeData:[_xmlDocument XMLData]];
	[super close];
}


@end
