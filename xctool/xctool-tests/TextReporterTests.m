
#import <SenTestingKit/SenTestingKit.h>

#import "Options.h"
#import "Options+Testing.h"
#import "Reporter+Testing.h"
#import "TextReporter.h"


@interface TextReporterTests : SenTestCase
@end

@implementation TextReporterTests

/**
 Just verify the plumbing works and our text reporters don't crash when getting
 fed events.  This is a really lame test - over time, we should add cases to
 actually verify output.
 */
- (void)testReporterDoesntCrash
{
  void (^pumpReporter)(Class, NSString *) = ^(Class cls, NSString *path) {
    NSLog(@"pumpReporter(%@, %@) ...", cls, path);
    Options *options = [[[Options alloc] init] autorelease];
    options.workspace = TEST_DATA @"TestProject-Library/TestProject-Library.xcodeproj";
    options.scheme = @"TestProject-Library";

    // Pump the events to make sure all the plumbing works and we don't crash.
    [cls outputDataWithEventsFromFile:path options:options];
  };

  pumpReporter([PlainTextReporter class], TEST_DATA @"JSONStreamReporter-build-good.txt");
  pumpReporter([PlainTextReporter class], TEST_DATA @"JSONStreamReporter-build-bad.txt");
  pumpReporter([PlainTextReporter class], TEST_DATA @"JSONStreamReporter-runtests.txt");

  pumpReporter([PrettyTextReporter class], TEST_DATA @"JSONStreamReporter-build-good.txt");
  pumpReporter([PrettyTextReporter class], TEST_DATA @"JSONStreamReporter-build-bad.txt");
  pumpReporter([PrettyTextReporter class], TEST_DATA @"JSONStreamReporter-runtests.txt");
}

@end
