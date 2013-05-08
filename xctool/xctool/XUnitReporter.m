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
	NSXMLElement *_testSuitesRootElement;
	NSMutableArray *_testEvents;
}

- (id)init
{
	if (self = [super init]) {
		_testSuitesRootElement = [[NSXMLElement alloc] initWithXMLString:@"<testsuites></testsuites>" error:nil];
		_xmlDocument = [[NSXMLDocument alloc] initWithRootElement:_testSuitesRootElement];
		[_xmlDocument setCharacterEncoding:@"UTF-8"];
	}
	return self;
}

- (void)beginTestSuite:(NSDictionary *)event
{
	_testEvents = [NSMutableArray array];
}

- (void)endTestSuite:(NSDictionary *)event
{
	NSString *suiteName = [event valueForKey:kReporter_EndTestSuite_SuiteKey];
	// Skip the wrapper test suites
	BOOL process = ([suiteName rangeOfString:@"Multiple Selected Tests"].location == NSNotFound && [suiteName rangeOfString:@".octest(Tests)"].location == NSNotFound && [suiteName rangeOfString:@"All tests"].location == NSNotFound);
	if (process) {
		NSInteger tests = [[event valueForKey:kReporter_EndTestSuite_TestCaseCountKey] integerValue];
		NSInteger failures = [[event valueForKey:kReporter_EndTestSuite_TotalFailureCountKey] integerValue];
		NSString *totalTime = [NSString stringWithFormat:@"%f", [[event valueForKey:kReporter_EndTestSuite_TotalDurationKey] doubleValue]];
		
		NSString *host = [[NSHost currentHost] name];
		
		NSError *xmlError = nil;

		NSString *suiteString = [NSString stringWithFormat:@"<testsuite errors=\"0\" failures=\"%ld\" hostname=\"%@\" name=\"%@\" tests=\"%ld\" time=\"%@\"></testsuite>", failures, host, suiteName, tests, totalTime];
		NSXMLElement *suiteElement = [[NSXMLElement alloc] initWithXMLString:suiteString error:&xmlError];
		
		if (xmlError == nil) {
			for (NSDictionary *testResult in _testEvents) {
				NSString *testName = [testResult valueForKey:kReporter_EndTest_TestKey];

				NSRange suiteNameRange = [testName rangeOfString:[NSString stringWithFormat:@"-[%@", suiteName]];
				if (suiteNameRange.location != NSNotFound) {
					testName = [testName stringByReplacingCharactersInRange:suiteNameRange withString:@""];
					testName = [testName stringByReplacingOccurrencesOfString:@"]" withString:@""];
					testName = [testName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
				}
				
				NSString *testTime = [NSString stringWithFormat:@"%f", [[testResult valueForKey:kReporter_EndTest_TotalDurationKey] doubleValue]];

				BOOL passed = [testResult[kReporter_EndTest_SucceededKey] boolValue];
				
				NSString *testString = [NSString stringWithFormat:@"<testcase classname=\"%@\" name=\"%@\" time=\"%@\"></testcase>", suiteName, testName, testTime];
				NSXMLElement *testElement = [[NSXMLElement alloc] initWithXMLString:testString error:&xmlError];
				if (passed == NO) {
					NSDictionary *exception = testResult[kReporter_EndTest_ExceptionKey];
					NSString *message = [NSString stringWithFormat:@"%@: %@", exception[kReporter_EndTest_Exception_NameKey], exception[kReporter_EndTest_Exception_ReasonKey]];
					NSString *location = [NSString stringWithFormat:@"%@:%@", exception[kReporter_EndTest_Exception_FilePathInProjectKey], exception[kReporter_EndTest_Exception_LineNumberKey]];
					
					NSString *failureString = [NSString stringWithFormat:@"<failure message=\"%@\" type=\"Failure\">%@</failure>", message, location];
					NSXMLElement *failureElement = [[NSXMLElement alloc] initWithXMLString:failureString error:&xmlError];
					if (xmlError == nil) {
						[testElement addChild:failureElement];
						xmlError = nil;
					}
					
					if ([testResult[kReporter_EndTest_OutputKey] length] > 0) {
						NSString *outputString = [NSString stringWithFormat:@"<system-out>%@</system-out>", testResult[kReporter_EndTest_OutputKey]];
						NSXMLElement *outputElement = [[NSXMLElement alloc] initWithXMLString:outputString error:&xmlError];
						if (xmlError == nil) {
							[testElement addChild:outputElement];
						}
					}
					
				}
				[suiteElement addChild:testElement];
			}
			[_testSuitesRootElement addChild:suiteElement];
		}
	}
}


- (void)endTest:(NSDictionary *)event
{
	[_testEvents addObject:event];
}

- (void)close
{
	[_outputHandle writeData:[_xmlDocument XMLData]];
	[super close];
}


@end
