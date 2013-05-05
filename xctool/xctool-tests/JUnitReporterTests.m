#import <SenTestingKit/SenTestingKit.h>

#import "JUnitReporter.h"
#import "Options.h"
#import "TestUtil.h"


@interface JUnitReporterTests : SenTestCase
@end

@implementation JUnitReporterTests

- (void)pumpEventsAndWriteTo:(NSFileHandle *)fileHandle {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    Options *options = [[Options alloc] init];
    options.workspace = TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj";
    options.scheme = @"TestProject-Library";
    JUnitReporter *reporter = (JUnitReporter *)[Reporter reporterWithName:@"junit"
             outputPath:@"-"
                options:options];
    [options release];
    options = nil;
    [reporter openWithStandardOutput:fileHandle error:nil];
    NSString *pathContents = [NSString stringWithContentsOfFile:TEST_DATA @"JSONStreamReporter-runtests.txt"
     encoding:NSUTF8StringEncoding
        error:nil];
    for (NSString *line in [pathContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        if (line.length == 0) {
            break;
        }
        [reporter handleEvent:[NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding]
            options:0
              error:nil]];
    }
    [fileHandle closeFile];
    [pool drain];
}

- (void)testTestResults {
    NSPipe *pipe = [[NSPipe alloc] init];
    [NSThread detachNewThreadSelector:@selector(pumpEventsAndWriteTo:) toTarget:self withObject:[pipe fileHandleForWriting]];
    NSData *tmpData = nil;
    NSMutableData *accumulatedData = [[NSMutableData alloc] init];
    while ((tmpData = [[pipe fileHandleForReading] availableData]) && [tmpData length]) {
        [accumulatedData appendData:tmpData];
    }
    tmpData = nil;
    [pipe release];
    pipe = nil;
    NSMutableString *xmlStr = [[NSMutableString alloc] initWithData:accumulatedData encoding:NSUTF8StringEncoding];
    [accumulatedData release];
    accumulatedData = nil;
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
    STAssertEqualObjects(@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<testsuites name=\"(null)\" tests=\"6\" failures=\"1\" errors=\"0\" time=\"\">\n\
\t<testsuite name=\"SomeTests\" tests=\"6\" failures=\"1\" errors=\"0\" time=\"\" timestamp=\"\">\n\
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
\t\t\t<system-out>2013-03-28 11:35:43.956 otest[64678:707] SDK: 6.1\n\
</system-out>\n\
\t\t</testcase>\n\
\t\t<testcase classname=\"SomeTests\" name=\"testStream\" time=\"\">\n\
\t\t\t<system-out>2013-03-28 11:35:43.957 otest[64678:707] &gt;&gt;&gt;&gt; i = 0\n\
2013-03-28 11:35:44.208 otest[64678:707] &gt;&gt;&gt;&gt; i = 1\n\
2013-03-28 11:35:44.459 otest[64678:707] &gt;&gt;&gt;&gt; i = 2\n\
</system-out>\n\
\t\t</testcase>\n\
\t\t<testcase classname=\"SomeTests\" name=\"testWillFail\" time=\"\">\n\
\t\t\t<failure message=\"&#39;a&#39; should be equal to &#39;b&#39; Strings aren&#39;t equal\" type=\"Failure\">/Users/fpotter/fb/git/fbobjc/Tools/xctool/xctool/xctool-tests/TestData/TestProject-Library/TestProject-LibraryTests/SomeTests.m:40</failure>\n\
\t\t</testcase>\n\
\t\t<testcase classname=\"SomeTests\" name=\"testWillPass\" time=\"\">\n\
\t\t</testcase>\n\
\t</testsuite>\n\
</testsuites>\n\
", xmlStr, @"JUnit XML should match");
    [xmlStr release];
    xmlStr = nil;
}

@end
