
#import <SenTestingKit/SenTestingKit.h>

#import "JUnitReporter.h"
#import "Options.h"
#import "Reporter+Testing.h"
#import "TestUtil.h"

@interface JUnitReporterTests : SenTestCase
@end

@implementation JUnitReporterTests

- (void)testTestResults {
  NSData *outputData =
    [JUnitReporter outputDataWithEventsFromFile:TEST_DATA @"JSONStreamReporter-runtests.txt"
                                        options:nil];
  NSMutableString *xmlStr = [[[NSMutableString alloc] initWithData:outputData
                                                          encoding:NSUTF8StringEncoding] autorelease];

  NSRegularExpression *timeRegex = [[NSRegularExpression alloc] initWithPattern:@"time=\\\"[0-9\\.]*\\\""
                                                                        options:0
                                                                          error:nil];
  [timeRegex replaceMatchesInString:xmlStr
                            options:0
                              range:NSMakeRange(0, [xmlStr length])
                       withTemplate:@"time=\"\""];
  [timeRegex release];
  timeRegex = [[NSRegularExpression alloc] initWithPattern:@"timestamp=\\\"[GMT:\\-0-9\\.]*\\\""
                                                                        options:0
                                                                          error:nil];
  [timeRegex replaceMatchesInString:xmlStr
                            options:0
                              range:NSMakeRange(0, [xmlStr length])
                       withTemplate:@"timestamp=\"\""];
  [timeRegex release];
  timeRegex = nil;
    STAssertEqualObjects(@"\
<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<testsuites name=\"TestProject-LibraryTests.octest\" tests=\"7\" failures=\"1\" errors=\"0\" time=\"\">\n\
\t<testsuite name=\"OtherTests\" tests=\"1\" failures=\"0\" errors=\"0\" time=\"\" timestamp=\"\">\n\
\t\t<testcase classname=\"OtherTests\" name=\"testSomething\" time=\"\">\n\
\t\t</testcase>\n\
\t</testsuite>\n\
\t<testsuite name=\"SomeTests\" tests=\"6\" failures=\"1\" errors=\"0\" time=\"\" timestamp=\"\">\n\
\t\t<testcase classname=\"SomeTests\" name=\"testBacktraceOutputIsCaptured\" time=\"\">\n\
\t\t\t<system-out>0   TestProject-LibraryTests            0x016c9827 -[SomeTests testBacktraceOutputIsCaptured] + 103\n\
1   CoreFoundation                      0x00a011bd __invoking___ + 29\n\
2   CoreFoundation                      0x00a010d6 -[NSInvocation invoke] + 342\n\
3   SenTestingKit                       0x20103ed1 -[SenTestCase invokeTest] + 219\n\
4   SenTestingKit                       0x2010405b -[SenTestCase performTest:] + 183\n\
5   SenTestingKit                       0x201037bf -[SenTest run] + 82\n\
6   SenTestingKit                       0x2010792b -[SenTestSuite performTest:] + 139\n\
7   SenTestingKit                       0x201037bf -[SenTest run] + 82\n\
8   SenTestingKit                       0x2010792b -[SenTestSuite performTest:] + 139\n\
9   SenTestingKit                       0x201037bf -[SenTest run] + 82\n\
10  SenTestingKit                       0x2010792b -[SenTestSuite performTest:] + 139\n\
11  SenTestingKit                       0x201037bf -[SenTest run] + 82\n\
12  SenTestingKit                       0x201063ec +[SenTestProbe runTests:] + 174\n\
13  libobjc.A.dylib                     0x007385c8 +[NSObject performSelector:withObject:] + 70\n\
14  otest                               0x00002342 otest + 4930\n\
15  otest                               0x000025ef otest + 5615\n\
16  otest                               0x0000268c otest + 5772\n\
17  otest                               0x00002001 otest + 4097\n\
18  otest                               0x00001f71 otest + 3953\n\
</system-out>\n\
\t\t</testcase>\n\
\t\t<testcase classname=\"SomeTests\" name=\"testOutputMerging\" time=\"\">\n\
\t\t\t<system-out>stdout-line1\n\
stderr-line1\n\
stdout-line2\n\
stdout-line3\n\
stderr-line2\n\
stderr-line3\n\
</system-out>\n\
\t\t</testcase>\n\
\t\t<testcase classname=\"SomeTests\" name=\"testPrintSDK\" time=\"\">\n\
\t\t\t<system-out>2013-05-08 20:51:11.809 otest[88423:707] SDK: 6.1\n\
</system-out>\n\
\t\t</testcase>\n\
\t\t<testcase classname=\"SomeTests\" name=\"testStream\" time=\"\">\n\
\t\t\t<system-out>2013-05-08 20:51:11.809 otest[88423:707] &gt;&gt;&gt;&gt; i = 0\n\
2013-05-08 20:51:12.060 otest[88423:707] &gt;&gt;&gt;&gt; i = 1\n\
2013-05-08 20:51:12.312 otest[88423:707] &gt;&gt;&gt;&gt; i = 2\n\
</system-out>\n\
\t\t</testcase>\n\
\t\t<testcase classname=\"SomeTests\" name=\"testWillFail\" time=\"\">\n\
\t\t\t<failure message=\"&apos;a&apos; should be equal to &apos;b&apos; Strings aren&apos;t equal\" type=\"Failure\">/Users/fpotter/xctool/xctool/xctool-tests/TestData/TestProject-Library/TestProject-LibraryTests/SomeTests.m:40</failure>\n\
\t\t</testcase>\n\
\t\t<testcase classname=\"SomeTests\" name=\"testWillPass\" time=\"\">\n\
\t\t</testcase>\n\
\t</testsuite>\n\
</testsuites>\n\
", xmlStr, @"JUnit XML should match");
}

@end
