//
// Copyright 2013 Facebook
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "TextReporter.h"

#import <sys/ioctl.h>
#import <unistd.h>

#import <QuartzCore/QuartzCore.h>

#import "Action.h"
#import "NSFileHandle+Print.h"
#import "ReporterEvents.h"
#import "RunTestsAction.h"

/**
 Remove leading component of string if it matches cwd.
 */
static NSString *abbreviatePath(NSString *string) {
  NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
  if (![cwd hasSuffix:@"/"]) {
    cwd = [cwd stringByAppendingString:@"/"];
  }
  if ([string hasPrefix:cwd]) {
    return [string substringFromIndex:cwd.length];
  }
  return string;
}


@interface ReportWriter : NSObject
{
}

@property (nonatomic, assign) NSInteger indent;
@property (nonatomic, assign) NSInteger savedIndent;
@property (nonatomic, assign) BOOL useColorOutput;
@property (nonatomic, retain) NSFileHandle *outputHandle;
@property (nonatomic, retain) NSString *lastLineUpdate;

- (id)initWithOutputHandle:(NSFileHandle *)outputHandle;

@end

@implementation ReportWriter

- (id)initWithOutputHandle:(NSFileHandle *)outputHandle
{
  if (self = [super init]) {
    self.outputHandle = outputHandle;
    _indent = 0;
    _savedIndent = -1;
  }
  return self;
}

- (void)dealloc
{
  self.outputHandle = nil;
  [super dealloc];
}

- (void)increaseIndent
{
  _indent++;
}

- (void)decreaseIndent
{
  assert(_indent > 0);
  _indent--;
}

- (void)disableIndent
{
  _savedIndent = _indent;
  _indent = 0;
}

- (void)enableIndent
{
  _indent = _savedIndent;
}

- (NSString *)formattedStringWithFormat:(NSString *)format arguments:(va_list)argList
{
  NSMutableString *str = [[[NSMutableString alloc] initWithFormat:format arguments:argList] autorelease];

  NSDictionary *ansiTags = @{@"<red>": @"\x1b[31m",
                             @"<green>": @"\x1b[32m",
                             @"<yellow>": @"\x1b[33m",
                             @"<blue>": @"\x1b[34m",
                             @"<magenta>": @"\x1b[35m",
                             @"<cyan>": @"\x1b[36m",
                             @"<white>": @"\x1b[37m",
                             @"<bold>": @"\x1b[1m",
                             @"<faint>": @"\x1b[2m",
                             @"<underline>": @"\x1b[4m",
                             @"<reset>": @"\x1b[0m",
                             };

  for (NSString *ansiTag in [ansiTags allKeys]) {
    NSString *replaceWith = self.useColorOutput ? ansiTags[ansiTag] : @"";
    [str replaceOccurrencesOfString:ansiTag withString:replaceWith options:0 range:NSMakeRange(0, [str length])];
  }

  if (_indent > 0) {
    [str insertString:[@"" stringByPaddingToLength:(_indent * 2) withString:@" " startingAtIndex:0]
              atIndex:0];
  }

  return str;
}

- (void)printString:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2)
{
  va_list args;
  va_start(args, format);
  NSString *str = [self formattedStringWithFormat:format arguments:args];
  [self.outputHandle writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
  va_end(args);
}

- (void)printNewline
{
  if (self.lastLineUpdate != nil && !_useColorOutput) {
    [self.outputHandle writeData:[self.lastLineUpdate dataUsingEncoding:NSUTF8StringEncoding]];
    self.lastLineUpdate = nil;
  }
  [self.outputHandle writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)updateLineWithFormat:(NSString *)format arguments:(va_list)argList
{
  NSString *line = [self formattedStringWithFormat:format arguments:argList];;

  if (_useColorOutput) {
    [self.outputHandle writeData:[@"\r" dataUsingEncoding:NSUTF8StringEncoding]];
    [self.outputHandle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
  } else {
    self.lastLineUpdate = line;
  }
}

- (void)updateLine:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2)
{
  va_list args;
  va_start(args, format);
  [self updateLineWithFormat:format arguments:args];
  va_end(args);
}

- (void)printLine:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2)
{
  va_list args;
  va_start(args, format);
  [self updateLineWithFormat:format arguments:args];
  [self printNewline];
  va_end(args);
}

@end

@implementation TextReporter

- (id)init
{
  if (self = [super init]) {
    _analyzerWarnings = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc
{
  [_currentBuildCommandEvent release];
  [_reportWriter release];
  [_currentStatusEvent release];
  [_failedTests release];
  [_currentBundle release];
  [_analyzerWarnings release];
  [super dealloc];
}

- (BOOL)openWithStandardOutput:(NSFileHandle *)standardOutput error:(NSString **)error
{
  if ([super openWithStandardOutput:standardOutput error:error]) {
    // self.outputHandle will either be a file handle for stdout or a file handle for
    // some file on disk.
    self.reportWriter = [[[ReportWriter alloc] initWithOutputHandle:self.outputHandle] autorelease];
    self.reportWriter.useColorOutput = _isPretty;
    return YES;
  } else {
    return NO;
  }
}

- (void)close
{
  // Always leave one blank line at the end - it looks a little nicer.
  [_reportWriter printNewline];
  [super close];
}

- (NSString *)passIndicatorString
{
  return _isPretty ? @"<green>\u2713<reset>" : @"~";
}

- (NSString *)warningIndicatorString
{
  return _isPretty ? @"<yellow>\u26A0<reset>" : @"!";
}

- (NSString *)failIndicatorString
{
  return _isPretty ? @"<red>\u2717<reset>" : @"X";
}

- (NSString *)emptyIndicatorString
{
  return _isPretty ? @" " : @" ";
}

- (void)printDividerWithDownLine:(BOOL)showDownLine
{
  struct winsize w = {0};
  ioctl(STDOUT_FILENO, TIOCGWINSZ, &w);
  int width = w.ws_col > 0 ? w.ws_col : 80;

  NSString *dashStr = nil;
  NSString *indicatorStr = nil;

  if (_isPretty) {
    dashStr = @"\u2501";
    indicatorStr = @"\u2533";
  } else {
    dashStr = @"-";
    indicatorStr = @"|";
  }

  NSString *dividier = [@"" stringByPaddingToLength:width withString:dashStr startingAtIndex:0];

  if (showDownLine) {
    dividier = [dividier stringByReplacingCharactersInRange:NSMakeRange(self.reportWriter.indent * 2, 1) withString:indicatorStr];
  }

  [self.reportWriter disableIndent];
  [self.reportWriter updateLine:@"<faint>%@<reset>", dividier];
  [self.reportWriter printNewline];
  [self.reportWriter enableIndent];
}

- (void)printDivider
{
  [self printDividerWithDownLine:NO];
}

- (void)printAnalyzerSummary
{
  if (self.analyzerWarnings.count > 0) {
    [self.reportWriter printLine:@"<bold>Analyzer Warnings:<reset>"];
    [self.reportWriter printNewline];
    [self.reportWriter increaseIndent];

    [self.analyzerWarnings enumerateObjectsUsingBlock:
     ^(NSDictionary *event, NSUInteger idx, BOOL *stop) {
       [self.reportWriter printLine:@"%lu) %@:%@:%@: %@:",
        (unsigned long)idx,
        abbreviatePath(event[kReporter_AnalyzerResult_FileKey]),
        event[kReporter_AnalyzerResult_LineKey],
        event[kReporter_AnalyzerResult_ColumnKey],
        event[kReporter_AnalyzerResult_DescriptionKey]];

       [self printDivider];
       [self.reportWriter disableIndent];
       [self.reportWriter printLine:@"<faint>%@<rest>",
        [TextReporter getContext:event[kReporter_AnalyzerResult_FileKey]
                       errorLine:[event[kReporter_AnalyzerResult_LineKey] intValue]
                       colNumber:[event[kReporter_AnalyzerResult_ColumnKey] intValue]]];
       [self.reportWriter printNewline];
       for (NSDictionary *piece in event[kReporter_AnalyzerResult_ContextKey]) {
         [self.reportWriter printLine:@"<faint>%@:%@:%@: %@<reset>",
          abbreviatePath(piece[@"file"]), piece[@"line"], piece[@"col"], piece[@"message"]];
       }
       [self.reportWriter enableIndent];
       [self printDivider];

       [self.reportWriter printNewline];
     }];

    [self.reportWriter decreaseIndent];
  }
}

- (NSString *)condensedBuildCommandTitle:(NSString *)title
{
  NSArray *parts = [title componentsSeparatedByString:@" "];
  NSMutableArray *newParts = [NSMutableArray array];

  for (NSString *part in parts) {
    if ([part rangeOfString:@"/"].length != 0) {
      // Looks like a path...
      [newParts addObject:[part lastPathComponent]];
    } else {
      [newParts addObject:part];
    }
  }

  return [newParts componentsJoinedByString:@" "];
}

- (void)beginAction:(NSDictionary *)event
{
  NSString *name = event[kReporter_BeginAction_NameKey];
  self.failedTests = [[[NSMutableArray alloc] init] autorelease];

  _testsTotal = 0;
  _testsPassed = 0;

  // Ensure there's one blank line between earlier output and this action.
  [_reportWriter printNewline];

  [self.reportWriter printLine:@"<bold>=== %@ ===<reset>", [name uppercaseString]];
  [self.reportWriter printNewline];
  [self.reportWriter increaseIndent];
}

- (void)endAction:(NSDictionary *)event
{
  [self.reportWriter decreaseIndent];

  NSString *name = event[kReporter_BeginAction_NameKey];
  BOOL succeeded = [event[kReporter_EndAction_SucceededKey] boolValue];
  double duration = [event[kReporter_EndAction_DurationKey] doubleValue];

  NSString *message = nil;
  NSString *status = succeeded ? @"SUCCEEDED" : @"FAILED";

  if ([name isEqualToString:@"run-tests"] || [name isEqualToString:@"test"]) {
    message = [NSString stringWithFormat:@"%lu of %lu tests passed", _testsPassed, _testsTotal];

    if ([self.failedTests count] > 0) {
      [self.reportWriter printLine:@"<bold>Failures:<reset>"];
      [self.reportWriter printNewline];
      [self.reportWriter increaseIndent];

      for (int failedIndex = 0; failedIndex < [self.failedTests count]; failedIndex++) {
        NSDictionary *test = self.failedTests[failedIndex];

        NSDictionary *testEvent = test[@"event"];

        [self.reportWriter printLine:@"%d) %@ (%@)",
         failedIndex,
         testEvent[kReporter_EndTest_TestKey],
         test[@"bundle"]
         ];

        NSDictionary *exception = testEvent[kReporter_EndTest_ExceptionKey];

        BOOL showInfo = ([testEvent[kReporter_EndTest_OutputKey] length] > 0) || (exception != nil);

        if (showInfo) {
          [self printDivider];
        }

        [self.reportWriter disableIndent];
        [self.reportWriter printString:@"<faint>%@<reset>", testEvent[kReporter_EndTest_OutputKey]];
        [self.reportWriter enableIndent];

        // Show exception, if any.
        if (exception) {
          [self.reportWriter disableIndent];
          [self.reportWriter printLine:@"<faint>%@:%d: %@: %@:<reset>",
           exception[kReporter_EndTest_Exception_FilePathInProjectKey],
           [exception[kReporter_EndTest_Exception_LineNumberKey] intValue],
           exception[kReporter_EndTest_Exception_NameKey],
           exception[kReporter_EndTest_Exception_ReasonKey]];
          [self.reportWriter printLine:@"<faint>%@<reset>",
           [TextReporter getContext:exception[kReporter_EndTest_Exception_FilePathInProjectKey]
                          errorLine:[exception[kReporter_EndTest_Exception_LineNumberKey] intValue]]];
          [self.reportWriter enableIndent];
        }

        if (showInfo) {
          [self printDivider];
        }
        [self.reportWriter printNewline];
      }
      [self.reportWriter decreaseIndent];
    }
  } else if ([name isEqual:@"analyze"]) {
    [self printAnalyzerSummary];
  }

  NSString *color = succeeded ? @"<green>" : @"<red>";
  [self.reportWriter printLine:@"<bold>%@** %@ %@%@ **<reset> <faint>(%03d ms)<reset>",
   color,
   [name uppercaseString],
   status,
   message != nil ? [@": " stringByAppendingString:message] : @"",
   (int)(duration * 1000)];
}

- (void)beginXcodebuild:(NSDictionary *)event
{
  [self.reportWriter printLine:@"xcodebuild <bold>%@<reset> <underline>%@<reset>",
   event[kReporter_BeginXcodebuild_CommandKey],
   event[kReporter_BeginXcodebuild_TitleKey]];
  [self.reportWriter increaseIndent];
}

- (void)endXcodebuild:(NSDictionary *)event
{
  [self.reportWriter decreaseIndent];

  BOOL xcodebuildHadError = ![event[kReporter_EndXcodebuild_ErrorMessageKey]
                              isKindOfClass:[NSNull class]];

  if (xcodebuildHadError) {
    NSString *errorMessage = event[kReporter_EndXcodebuild_ErrorMessageKey];

    [self printDivider];
    [_reportWriter disableIndent];
    [_reportWriter printLine:@"%@", [errorMessage stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]]];
    [_reportWriter enableIndent];
    [self printDivider];
  }

  [self.reportWriter printNewline];
}

- (void)beginBuildTarget:(NSDictionary *)event
{
  [self.reportWriter printLine:@"<bold>%@<reset> / <bold>%@<reset> (%@)",
   event[kReporter_BeginBuildTarget_ProjectKey],
   event[kReporter_BeginBuildTarget_TargetKey],
   event[kReporter_BeginBuildTarget_ConfigurationKey]];
  [self.reportWriter increaseIndent];
}

- (void)endBuildTarget:(NSDictionary *)event
{
  [self.reportWriter decreaseIndent];
  [self.reportWriter printNewline];
}

- (void)beginBuildCommand:(NSDictionary *)event
{
  [self.reportWriter updateLine:@"%@ %@",
   [self emptyIndicatorString],
   [self condensedBuildCommandTitle:event[kReporter_BeginBuildCommand_TitleKey]]];
  self.currentBuildCommandEvent = event;
}

- (void)endBuildCommand:(NSDictionary *)event
{
  NSString *(^formattedBuildDuration)(float) = ^(float duration){
    NSString *color = nil;

    if (duration <= 0.05f) {
      color = @"<faint><green>";
    } else if (duration <= 0.2f) {
      color = @"<green>";
    } else if (duration <= 0.5f) {
      color = @"<yellow>";
    } else {
      color = @"<red>";
    }

    return [NSString stringWithFormat:@"%@(%d ms)<reset>", color, (int)(duration * 1000)];
  };

  BOOL succeeded = [event[kReporter_EndBuildCommand_SucceededKey] boolValue];
  NSString *outputText = [event[kReporter_EndBuildCommand_EmittedOutputTextKey]
                          stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  NSString *indicator = nil;
  if (succeeded) {
    if ([outputText rangeOfString:@"warning:"].location != NSNotFound) {
      indicator = [self warningIndicatorString];
    } else {
      indicator = [self passIndicatorString];
    }
  } else {
    indicator = [self failIndicatorString];
  }

  [self.reportWriter updateLine:@"%@ %@ %@",
   indicator,
   [self condensedBuildCommandTitle:event[kReporter_EndBuildCommand_TitleKey]],
   formattedBuildDuration([event[kReporter_EndBuildCommand_DurationKey] floatValue])];
  [self.reportWriter printNewline];

  BOOL showInfo = !succeeded || (outputText.length > 0);

  if (showInfo) {
    [self printDivider];
    [self.reportWriter disableIndent];

    // If the command failed, it's always interesting to see the full command being run.
    if (!succeeded) {
      [self.reportWriter printLine:@"<faint>%@<reset>", self.currentBuildCommandEvent[kReporter_BeginBuildCommand_CommandKey]];
    }

    if (outputText.length > 0) {
      [self.reportWriter printLine:@"<faint>%@<reset>", outputText];
    }

    [self.reportWriter enableIndent];
    [self printDivider];
  }

  self.currentBuildCommandEvent = event;
}

- (void)beginOcunit:(NSDictionary *)event
{
  NSArray *attributes = @[event[kReporter_BeginOCUnit_SDKNameKey],
                          event[kReporter_BeginOCUnit_TestTypeKey],
                          [NSString stringWithFormat:@"GC %@",
                           [event[kReporter_BeginOCUnit_GCEnabledKey] boolValue] ? @"ON" : @"OFF"]];


  [self.reportWriter printLine:@"<bold>run-test<reset> <underline>%@<reset> (%@)",
   event[kReporter_BeginOCUnit_BundleNameKey],
   [attributes componentsJoinedByString:@", "]];
  self.currentBundle = event[kReporter_BeginOCUnit_BundleNameKey];
  [self.reportWriter increaseIndent];
}

- (void)endOcunit:(NSDictionary *)event
{
  [self.reportWriter decreaseIndent];

  if (![event[kReporter_EndOCUnit_SucceededKey] boolValue] &&
      ![event[kReporter_EndOCUnit_FailureReasonKey] isEqual:[NSNull null]]) {
    [self.reportWriter printLine:@"<bold>failed<reset>: %@", event[kReporter_EndOCUnit_FailureReasonKey]];
  }
}

- (void)beginTestSuite:(NSDictionary *)event
{
  NSString *suite = event[kReporter_BeginTestSuite_SuiteKey];

  if (![suite isEqualToString:@"All tests"] && ![suite hasSuffix:@".octest(Tests)"]) {
    if ([suite hasPrefix:@"/"]) {
      suite = [suite lastPathComponent];
    }

    [self.reportWriter printLine:@"<bold>suite<reset> <underline>%@<reset>", suite];
    [self.reportWriter increaseIndent];
  }
}

- (void)endTestSuite:(NSDictionary *)event
{
  NSString *suite = event[kReporter_EndTestSuite_SuiteKey];
  int testCaseCount = [event[kReporter_EndTestSuite_TestCaseCountKey] intValue];
  int totalFailureCount = [event[kReporter_EndTestSuite_TotalFailureCountKey] intValue];

  if (![suite isEqualToString:@"All tests"] && ![suite hasSuffix:@".octest(Tests)"]) {
    [self.reportWriter printLine:@"<bold>%d of %d tests passed %@<reset>",
     (testCaseCount - totalFailureCount),
     testCaseCount,
     [self formattedTestDuration:[event[kReporter_EndTestSuite_TotalDurationKey] floatValue] withColor:NO]
     ];
    [self.reportWriter decreaseIndent];
    [self.reportWriter printNewline];
  } else if ([suite isEqualToString:@"All tests"] && totalFailureCount > 0) {
    [self.reportWriter printLine:@"<bold>%d of %d tests passed %@<reset>",
     (testCaseCount - totalFailureCount),
     testCaseCount,
     [self formattedTestDuration:[event[kReporter_EndTestSuite_TotalDurationKey] floatValue] withColor:NO]
     ];
    [self.reportWriter printNewline];
  }
}

- (void)beginTest:(NSDictionary *)event
{
  [self.reportWriter updateLine:@"%@ %@", [self emptyIndicatorString], event[kReporter_BeginTest_TestKey]];
  self.testHadOutput = NO;
}

- (void)testOutput:(NSDictionary *)event {
  if (!self.testHadOutput) {
    [self.reportWriter printNewline];
    [self printDivider];
  }

  [self.reportWriter disableIndent];
  [self.reportWriter printString:@"<faint>%@<reset>", event[@"output"]];
  [self.reportWriter enableIndent];

  self.testHadOutput = YES;
  self.testOutputEndsInNewline = [event[kReporter_TestOutput_OutputKey] hasSuffix:@"\n"];
}

- (void)beginStatus:(NSDictionary *)event
{
  NSAssert(_currentStatusEvent == nil,
           @"An earlier begin-status event never followed with a end-status event.");

  _currentStatusEvent = [event retain];

  // We purposely don't output a newline - this way endStatus: can have a chance
  // to send a \r and rewrite the existing line.
  [_reportWriter updateLine:@"[%@] %@",
   event[kReporter_BeginStatus_LevelKey],
   event[kReporter_BeginStatus_MessageKey]
   ];
}

- (void)endStatus:(NSDictionary *)event
{
  NSAssert(_currentStatusEvent != nil,
           @"an end-status event must be preceded by a begin-status event.");

  double duration = ([event[kReporter_EndStatus_TimestampKey] doubleValue] -
                     [_currentStatusEvent[kReporter_BeginStatus_TimestampKey] doubleValue]);

  NSMutableString *line = [NSMutableString string];
  [line appendFormat:@"[%@] ", event[kReporter_EndStatus_LevelKey]];
  [line appendString:event[kReporter_EndStatus_MessageKey]];
  if (duration > 0) {
    [line appendFormat:@" %@", [self formattedTestDuration:duration withColor:NO]];
  }

  [_reportWriter updateLine:@"%@", line];
  [_reportWriter printNewline];

  [_currentStatusEvent release];
  _currentStatusEvent = nil;
}

- (NSString *)formattedTestDuration:(float)duration withColor:(BOOL)withColor
{
  NSString *color = nil;

  if (duration <= 0.05f) {
    color = @"<faint><green>";
  } else if (duration <= 0.2f) {
    color = @"<green>";
  } else if (duration <= 0.5f) {
    color = @"<yellow>";
  } else {
    color = @"<red>";
  }

  if (withColor) {
    return [NSString stringWithFormat:@"%@(%d ms)<reset>", color, (int)(duration * 1000)];
  } else {
    return [NSString stringWithFormat:@"(%d ms)", (int)(duration * 1000)];
  }
};

- (void)endTest:(NSDictionary *)event
{
  BOOL succeeded = [event[kReporter_EndTest_SucceededKey] boolValue];
  BOOL showInfo = !succeeded || ([event[kReporter_EndTest_OutputKey] length] > 0);
  NSString *indicator = nil;

  if (succeeded) {
    indicator = [self passIndicatorString];
  } else {
    indicator = [self failIndicatorString];
  }

  if (showInfo) {
    if (!self.testHadOutput) {
      [self.reportWriter printNewline];
      [self printDivider];
    }

    [self.reportWriter disableIndent];

    // Show exception, if any.
    NSDictionary *exception = event[kReporter_EndTest_ExceptionKey];
    if (exception) {
      [self.reportWriter printLine:@"<faint>%@:%d: %@: %@:<reset>",
       exception[kReporter_EndTest_Exception_FilePathInProjectKey],
       [exception[kReporter_EndTest_Exception_LineNumberKey] intValue],
       exception[kReporter_EndTest_Exception_NameKey],
       exception[kReporter_EndTest_Exception_ReasonKey]];
      [self.reportWriter printLine:@"<faint>%@<reset>",
       [TextReporter getContext:exception[kReporter_EndTest_Exception_FilePathInProjectKey]
                      errorLine:[exception[kReporter_EndTest_Exception_LineNumberKey] intValue]]];
    }

    [self.reportWriter enableIndent];
    [self printDividerWithDownLine:YES];
  }

  NSMutableString *resultLine = [NSMutableString stringWithFormat:@"%@ %@ %@",
                                 indicator,
                                 event[kReporter_EndTest_TestKey],
                                 [self formattedTestDuration:[event[kReporter_EndTest_TotalDurationKey] floatValue] withColor:YES]
                                 ];

  // If the test failed, add a number linking it to the failure summary.
  if (!succeeded) {
    [resultLine appendFormat:@" (%ld)", [self.failedTests count]];

    // Add the test information to the list of failed tests for printing later.
    [self.failedTests addObject:@{@"bundle": self.currentBundle, @"event": event}];
  }

  [self.reportWriter updateLine:@"%@", resultLine];
  [self.reportWriter printNewline];

  _testsTotal++;
  if (succeeded) {
    _testsPassed++;
  }
}

- (void)analyzerResult:(NSDictionary *)event
{
  [self.analyzerWarnings addObject:event];
}

+ (NSString *)getContext:(NSString *)filePath errorLine:(int)errorLine colNumber:(int)colNumber
{
  BOOL isDirectory = NO;
  BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];
  if (fileExists && !isDirectory) {
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:filePath
                                                       encoding:NSUTF8StringEncoding
                                                          error:&error];
    if (error) {
      NSLog(@"Error loading file %@: %@", filePath, [error localizedFailureReason]);
      return nil;
    } else {
      NSMutableString *context = [NSMutableString string];
      NSArray *lines = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
      int start = MAX(0, errorLine - 4);
      int end = MIN((int)[lines count], errorLine + 2);
      // Give all line numbers the same width even if they roll over to a new power of 10.
      int lineNoLength = floor(log10(end)) + 1;
      NSString *formatString = [NSString stringWithFormat:@"%@%d%@", @"%", lineNoLength, @"d %@"];
      for (int lineNo = start; lineNo < end; lineNo++) {
        NSString *lineStr = [[lines objectAtIndex:lineNo] description];
        // Careful: Line numbers start at 1 but array indices start at 0.
        [context appendFormat:formatString, lineNo + 1, lineStr];
        if (lineNo + 1 == errorLine) {
          // Leading whitespace for underline so it's under the text only.
          int nonWhitespaceLoc = (int)[lineStr rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]].location;
          NSString *trimmedLineStr = [lineStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
          int whitespaceLength = lineNoLength + 1 + nonWhitespaceLoc;
          NSMutableString *ulineStr = [NSMutableString stringWithString:[[[NSString string]
                                                                          stringByPaddingToLength:whitespaceLength
                                                                          withString:@" "
                                                                          startingAtIndex:0]
                                                                         stringByPaddingToLength:[trimmedLineStr length] +whitespaceLength
                                                                         withString:@"~"
                                                                         startingAtIndex:0]];
          if (colNumber > 0 && colNumber <= [lineStr length]) {
            [ulineStr replaceCharactersInRange:NSMakeRange(lineNoLength + colNumber, 1) withString:@"^"];
          }
          [context appendFormat:@"\n%@", ulineStr];
        }
        if (lineNo + 1 < end) {
          [context appendString:@"\n"];
        }
      }
      return context;
    }
  } else {
    NSLog(@"ERROR: couldn't load file: %@\n", filePath);
    return nil;
  }
}

+ (NSString *)getContext:(NSString *)filePath errorLine:(int)errorLine
{
  return [TextReporter getContext:filePath errorLine:errorLine colNumber:0];
}

@end

@implementation PrettyTextReporter

- (id)init
{
  if (self = [super init]) {
    // Be pretty so long as stdout looks like a nice TTY.
    _isPretty = isatty(STDOUT_FILENO);
  }
  return self;
}

+ (NSDictionary *)reporterInfo {
  return @{kReporterInfoNameKey : @"pretty",
           kReporterInfoDescriptionKey : @"ANSI-colored build and test results (default).",
           };
}

@end

@implementation PlainTextReporter

- (id)init
{
  if (self = [super init]) {
    _isPretty = NO;
  }
  return self;
}

+ (NSDictionary *)reporterInfo {
  return @{kReporterInfoNameKey : @"plain",
           kReporterInfoDescriptionKey : @"Plain text build and test results.",
           };
}


@end
