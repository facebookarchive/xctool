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
	assertThat(resultsString, equalTo(@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?><testsuites></testsuites>"));
}

- (void)testBadBuild
{
	Options *options = [[Options alloc] init];
	options.workspace = TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj";
	options.scheme = @"TestProject-Library";
	XUnitReporter *reporter = [self reporterPumpedWithEventsFrom:TEST_DATA @"JSONStreamReporter-build-bad.txt" options:options];
	
	NSXMLDocument *results = reporter.xmlDocument;
	NSString *resultsString = [results XMLString];
	
	assertThat(results, notNilValue());
	assertThat(resultsString, equalTo(@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?><testsuites></testsuites>"));
}

- (void)testTestResults
{
	Options *options = [[Options alloc] init];
	options.workspace = TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj";
	options.scheme = @"TestProject-Library";
	XUnitReporter *reporter = [self reporterPumpedWithEventsFrom:TEST_DATA @"JSONStreamReporter-runtests.txt" options:options];
	
	NSXMLDocument *results = reporter.xmlDocument;
	NSString *resultsString = [results XMLString];
	
	NSString *expectedResults = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?><testsuites><testsuite errors=\"0\" failures=\"1\" hostname=\"%@\" name=\"SomeTests\" tests=\"6\" time=\"0.757224\"><testcase classname=\"SomeTests\" name=\"testOutputMerging\" time=\"0.000138\"></testcase><testcase classname=\"SomeTests\" name=\"testPrintSDK\" time=\"0.000504\"></testcase><testcase classname=\"SomeTests\" name=\"testStream\" time=\"0.752635\"></testcase><testcase classname=\"SomeTests\" name=\"testWillFail\" time=\"0.000118\"><failure message=\"SenTestFailureException: 'a' should be equal to 'b' Strings aren't equal\" type=\"Failure\">/Users/fpotter/fb/git/fbobjc/Tools/xctool/xctool/xctool-tests/TestData/TestProject-Library/TestProject-LibraryTests/SomeTests.m:40</failure><system-out>2013-03-28 11:35:43.957 otest[64678:707] >>>> i = 0\n2013-03-28 11:35:44.208 otest[64678:707] >>>> i = 1\n2013-03-28 11:35:44.459 otest[64678:707] >>>> i = 2\n</system-out></testcase><testcase classname=\"SomeTests\" name=\"testWillPass\" time=\"0.000032\"></testcase></testsuite></testsuites>", [[NSHost currentHost] name]];;
	
	assertThat(results, notNilValue());
	assertThat(resultsString, equalTo(expectedResults));
}


@end
