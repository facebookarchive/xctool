
#import <Foundation/Foundation.h>
#import "Reporter.h"

@class ReportWriter;

@interface TextReporter : Reporter
{
  BOOL _isPretty;
}

@property (nonatomic, retain) NSDictionary *currentBuildCommandEvent;
@property (nonatomic, assign) BOOL testHadOutput;
@property (nonatomic, assign) BOOL testOutputEndsInNewline;
@property (nonatomic, retain) ReportWriter *reportWriter;

@end

@interface PrettyTextReporter : TextReporter
@end

@interface PlainTextReporter : TextReporter
@end