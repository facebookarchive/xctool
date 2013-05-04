//
//  XUnitReporterTests.m
//  xctool
//
//  Created by Justin Mutter on 2013-05-03.
//  Copyright (c) 2013 Fred Potter. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "Options.h"
#import "TestUtil.h"
#import "XUnitReporter.h"

@interface XUnitReporterTests : SenTestCase
@end

@implementation XUnitReporterTests

- (XUnitReporter *)reporterPumpedWithEventsFrom:(NSString *)path options:(Options *)options
{
	XUnitReporter *reporter = (XUnitReporter *)[Reporter reporterWithName:@"xunit" outputPath:@"-" options:options];
	[reporter openWithStandardOutput:[NSFileHandle fileHandleWithNullDevice] error:nil];
	
	NSString *pathContents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	
	for (NSString *line in [pathContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
		if (line.length == 0) {
			break;
		}
		[reporter handleEvent:[NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil]];
	}
	return reporter;
}

- (void)testGoodBuild
{
	Options *options = [[Options alloc] init];
	options.workspace = TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj";
	options.scheme = @"TestProject-Library";
	XUnitReporter *reporter = [self reporterPumpedWithEventsFrom:TEST_DATA @"JSONStreamReporter-build-good.txt" options:options];
	
	NSXMLDocument *results = reporter.xmlDocument;
	NSString *resultsString = [results XMLString];
	
	assertThat(results, notNilValue());
	assertThat(resultsString, equalTo(@"<testsuites></testsuites>"));
}

- (void)testBadBuild
{
	Options *options = [[Options alloc] init];
	options.workspace = TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj";
	options.scheme = @"TestProject-Library";
	XUnitReporter *reporter = [self reporterPumpedWithEventsFrom:TEST_DATA @"JSONStreamReporter-build-bad.txt" options:options];
	
	NSXMLDocument *results = reporter.xmlDocument;
	NSString *resultsString = [results XMLString];
	
	NSLog(@"%@", resultsString);
	
	assertThat(results, notNilValue());
	assertThat(resultsString, equalTo(@"<testsuites></testsuites>"));
}

- (void)testTestResults
{
	Options *options = [[Options alloc] init];
	options.workspace = TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj";
	options.scheme = @"TestProject-Library";
	XUnitReporter *reporter = [self reporterPumpedWithEventsFrom:TEST_DATA @"JSONStreamReporter-runtests.txt" options:options];
	
	NSXMLDocument *results = reporter.xmlDocument;
	NSString *resultsString = [results XMLString];
	
	NSString *expectedResults = [NSString stringWithFormat:@"<testsuites><testsuite errors=\"0\" failures=\"1\" hostname=\"%@\" name=\"SomeTests\" tests=\"6\" time=\"0.757224\"><testcase classname=\"SomeTests\" name=\"testOutputMerging\" time=\"0.000138\"></testcase><testcase classname=\"SomeTests\" name=\"testPrintSDK\" time=\"0.000504\"></testcase><testcase classname=\"SomeTests\" name=\"testStream\" time=\"0.752635\"></testcase><testcase classname=\"SomeTests\" name=\"testWillFail\" time=\"0.000118\"><failure message=\"SenTestFailureException: 'a' should be equal to 'b' Strings aren't equal\" type=\"Failure\">/Users/fpotter/fb/git/fbobjc/Tools/xctool/xctool/xctool-tests/TestData/TestProject-Library/TestProject-LibraryTests/SomeTests.m:40</failure></testcase><testcase classname=\"SomeTests\" name=\"testWillPass\" time=\"0.000032\"></testcase></testsuite></testsuites>", [[NSHost currentHost] name]];;
	
	assertThat(results, notNilValue());
	assertThat(resultsString, equalTo(expectedResults));
}


@end
