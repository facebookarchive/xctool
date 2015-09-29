//
// Copyright 2004-present Facebook. All Rights Reserved.
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

#import "NSFileHandle+Print.h"
#import "ReporterEvents.h"
#import "TestResultCounter.h"

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

@property (nonatomic, assign) NSInteger indent;
@property (nonatomic, assign) NSInteger savedIndent;
@property (nonatomic, assign) BOOL useColorOutput;
@property (nonatomic, assign) BOOL useOverwrite;
@property (nonatomic, strong) NSFileHandle *outputHandle;
@property (nonatomic, copy) NSString *lastLineUpdate;

- (instancetype)initWithOutputHandle:(NSFileHandle *)outputHandle;

@end

@implementation ReportWriter

- (instancetype)initWithOutputHandle:(NSFileHandle *)outputHandle
{
  if (self = [super init]) {
    _outputHandle = outputHandle;
    _indent = 0;
    _savedIndent = -1;
  }
  return self;
}


- (void)increaseIndent
{
  _indent++;
}

- (void)decreaseIndent
{
  NSAssert(_indent > 0, @"Indent should be increased before being decreased");
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
  NSMutableString *str = [[NSMutableString alloc] initWithFormat:format arguments:argList];

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
    NSString *replaceWith = _useColorOutput ? ansiTags[ansiTag] : @"";
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
  [_outputHandle writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
  va_end(args);
}

- (void)printNewline
{
  if (_lastLineUpdate != nil && !(_useColorOutput && _useOverwrite)) {
    [_outputHandle writeData:[_lastLineUpdate dataUsingEncoding:NSUTF8StringEncoding]];
    _lastLineUpdate = nil;
  }
  [_outputHandle writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)updateLineWithFormat:(NSString *)format arguments:(va_list)argList
{
  NSString *line = [self formattedStringWithFormat:format arguments:argList];;

  if (_useColorOutput && _useOverwrite) {
    [_outputHandle writeData:[@"\r" dataUsingEncoding:NSUTF8StringEncoding]];
    [_outputHandle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
  } else {
    _lastLineUpdate = line;
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

@interface TextReporter ()
@property (nonatomic, assign) BOOL isPretty;
@property (nonatomic, assign) BOOL canOverwrite;
@property (nonatomic, strong) TestResultCounter *resultCounter;
@property (nonatomic, copy) NSDictionary *currentStatusEvent;
@property (nonatomic, copy) NSDictionary *currentBuildCommandEvent;
@property (nonatomic, assign) BOOL testHadOutput;
@property (nonatomic, assign) BOOL testOutputEndsInNewline;
@property (nonatomic, strong) ReportWriter *reportWriter;
@property (nonatomic, copy) NSMutableArray *failedTests;
@property (nonatomic, copy) NSString *currentBundle;
@property (nonatomic, copy) NSMutableArray *analyzerWarnings;
@property (nonatomic, copy) NSMutableArray *failedBuildEvents;
@property (nonatomic, copy) NSMutableArray *failedOcunitEvents;
@end

@implementation TextReporter

- (instancetype)init
{
  if (self = [super init]) {
    _analyzerWarnings = [[NSMutableArray alloc] init];
    _resultCounter = [[TestResultCounter alloc] init];
    _failedBuildEvents = [[NSMutableArray alloc] init];
    _failedOcunitEvents = [[NSMutableArray alloc] init];
  }
  return self;
}


- (void)willBeginReporting
{
  _reportWriter = [[ReportWriter alloc] initWithOutputHandle:_outputHandle];
  _reportWriter.useColorOutput = _isPretty;
  _reportWriter.useOverwrite = _canOverwrite;
}

- (void)didFinishReporting
{
  // Always leave one blank line at the end - it looks a little nicer.
  [_reportWriter printNewline];
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
  return _isPretty ? @"<red>\u2717<reset>" : @"x";
}

- (NSString *)errorIndicatorString
{
  return _isPretty ? @"<red>\u2602<reset>" : @"X";
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

  // Travis will claim its terminal width is 80 chars, but unless your browser
  // window is really large, you don't generally see an 80-char-width terminal.
  // This ends up making the divider lines wrap and look really ugly.  Let's cap
  // at 60.
  if ([[[NSProcessInfo processInfo] environment][@"TRAVIS"] isEqualToString:@"true"]) {
    width = MIN(width, 60);
  }

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
    dividier = [dividier stringByReplacingCharactersInRange:NSMakeRange(_reportWriter.indent * 2, 1) withString:indicatorStr];
  }

  [_reportWriter disableIndent];
  [_reportWriter updateLine:@"<faint>%@<reset>", dividier];
  [_reportWriter printNewline];
  [_reportWriter enableIndent];
}

- (void)printDivider
{
  [self printDividerWithDownLine:NO];
}

- (void)printAnalyzerSummary
{
  if (_analyzerWarnings.count > 0) {
    [_reportWriter printLine:@"<bold>Analyzer Warnings:<reset>"];
    [_reportWriter printNewline];
    [_reportWriter increaseIndent];

    [_analyzerWarnings enumerateObjectsUsingBlock:
     ^(NSDictionary *event, NSUInteger idx, BOOL *stop) {
       [_reportWriter printLine:@"%lu) %@:%@:%@: %@:",
        (unsigned long)idx,
        abbreviatePath(event[kReporter_AnalyzerResult_FileKey]),
        event[kReporter_AnalyzerResult_LineKey],
        event[kReporter_AnalyzerResult_ColumnKey],
        event[kReporter_AnalyzerResult_DescriptionKey]];

       [self printDivider];
       [_reportWriter disableIndent];
       [_reportWriter printLine:@"<faint>%@<rest>",
        [TextReporter getContext:event[kReporter_AnalyzerResult_FileKey]
                       errorLine:[event[kReporter_AnalyzerResult_LineKey] intValue]
                       colNumber:[event[kReporter_AnalyzerResult_ColumnKey] intValue]]];
       [_reportWriter printNewline];
       for (NSDictionary *piece in event[kReporter_AnalyzerResult_ContextKey]) {
         [_reportWriter printLine:@"<faint>%@:%@:%@: %@<reset>",
          abbreviatePath(piece[@"file"]), piece[@"line"], piece[@"col"], piece[@"message"]];
       }
       [_reportWriter enableIndent];
       [self printDivider];

       [_reportWriter printNewline];
     }];

    [_reportWriter decreaseIndent];
  }
}

- (NSString *)condensedBuildCommandTitle:(NSString *)title
{
  NSMutableArray *parts = [NSMutableArray array];
  NSRange pathRange = [title rangeOfString:@"/"];
  if (pathRange.location != NSNotFound) {
    NSString *command = [[title substringToIndex:pathRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *path = [title substringFromIndex:pathRange.location];
    [parts addObject:command ?: @""];
    [parts addObject:[path lastPathComponent] ?: @""];
  } else {
    [parts addObject:title];
  }

  return [parts componentsJoinedByString:@" "];
}

- (void)beginAction:(NSDictionary *)event
{
  NSString *name = event[kReporter_BeginAction_NameKey];
  _failedTests = [[NSMutableArray alloc] init];

  // Ensure there's one blank line between earlier output and this action.
  [_reportWriter printNewline];

  [_reportWriter printLine:@"<bold>=== %@ ===<reset>", [name uppercaseString]];
  [_reportWriter printNewline];
  [_reportWriter increaseIndent];
}

- (void)endAction:(NSDictionary *)event
{
  [_reportWriter decreaseIndent];
  [_reportWriter printNewline];

  NSString *name = event[kReporter_BeginAction_NameKey];
  BOOL succeeded = [event[kReporter_EndAction_SucceededKey] boolValue];
  double duration = [event[kReporter_EndAction_DurationKey] doubleValue];

  NSString *message = nil;
  NSString *status = succeeded ? @"SUCCEEDED" : @"FAILED";

  if (_failedBuildEvents.count > 0) {
    [_reportWriter printLine:@"<bold>Failures:<reset>"];
    [_reportWriter printNewline];
    [_reportWriter increaseIndent];

    int i = 0;
    for (NSDictionary *d in _failedBuildEvents) {
      [_reportWriter printLine:@"%d) %@", i, d[@"title"]];
      [self printDivider];
      [_reportWriter disableIndent];
      [_reportWriter printString:@"<faint>%@<reset>", d[@"body"]];
      [_reportWriter enableIndent];
      [self printDivider];
      [_reportWriter printNewline];
      i++;
    }
    [_reportWriter decreaseIndent];
  } else if ([name isEqualToString:@"run-tests"] || [name isEqualToString:@"test"]) {
    message = [NSString stringWithFormat:@"%lu passed, %lu failed, %lu errored, %lu total",
               [_resultCounter actionPassed],
               [_resultCounter actionFailed],
               [_resultCounter actionErrored],
               [_resultCounter actionTotal]];

    if ([_failedTests count] > 0 || [_failedOcunitEvents count] > 0) {
      [_reportWriter printLine:@"<bold>Failures:<reset>"];
      [_reportWriter printNewline];
      [_reportWriter increaseIndent];

      int i = 0;
      for (NSDictionary *ocUnitEvent in _failedOcunitEvents) {
        if (ocUnitEvent[kReporter_BeginOCUnit_BundleNameKey]) {
          [_reportWriter printLine:@"%d) %@ (%@)", i, ocUnitEvent[kReporter_BeginOCUnit_TargetNameKey], ocUnitEvent[kReporter_BeginOCUnit_BundleNameKey]];
        } else {
          [_reportWriter printLine:@"%d) %@", i, ocUnitEvent[kReporter_BeginOCUnit_TargetNameKey]];
        }
        [self printDivider];
        [_reportWriter disableIndent];
        [_reportWriter printString:@"<faint>%@\n<reset>", [ocUnitEvent[kReporter_EndOCUnit_MessageKey]
                                                               stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        [_reportWriter enableIndent];
        [self printDivider];
        [_reportWriter printNewline];
        i++;
      }
      for (int failedIndex = 0; failedIndex < [_failedTests count]; failedIndex++) {
        NSDictionary *test = _failedTests[failedIndex];

        NSDictionary *testEvent = test[kReporter_Event_Key];

        [_reportWriter printLine:@"%d) %@ (%@)",
         failedIndex + i,
         testEvent[kReporter_EndTest_TestKey],
         test[@"bundle"]
         ];

        NSArray *exceptions = testEvent[kReporter_EndTest_ExceptionsKey];

        BOOL showInfo = ([testEvent[kReporter_EndTest_OutputKey] length] > 0) || ([exceptions count] > 0);

        if (showInfo) {
          [self printDivider];
        }

        [_reportWriter disableIndent];

        NSString *testOutput = testEvent[kReporter_EndTest_OutputKey];
        [_reportWriter printString:@"<faint>%@<reset>", testOutput];
        if (![testOutput hasSuffix:@"\n"]) {
          [_reportWriter printNewline];
        }

        [_reportWriter enableIndent];

        // Show first exception, if any.
        if ([exceptions count] > 0) {
          NSDictionary *exception = exceptions[0];
          NSString *filePath = exception[kReporter_EndTest_Exception_FilePathInProjectKey];
          int lineNumber = [exception[kReporter_EndTest_Exception_LineNumberKey] intValue];

          [_reportWriter disableIndent];

          [_reportWriter printLine:@"<faint>%@:%d: %@:<reset>",
           filePath,
           lineNumber,
           exception[kReporter_EndTest_Exception_ReasonKey]];

          if ([[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:nil]) {
            NSString *context = [TextReporter getContext:filePath errorLine:lineNumber];
            [_reportWriter printLine:@"<faint>%@<reset>", context];
          }

          [_reportWriter enableIndent];
        }

        if (showInfo) {
          [self printDivider];
        }
        [_reportWriter printNewline];
      }
      [_reportWriter decreaseIndent];
    }
  } else if ([name isEqual:@"analyze"]) {
    [self printAnalyzerSummary];
  }

  NSString *color = succeeded ? @"<green>" : @"<red>";
  [_reportWriter printLine:@"<bold>%@** %@ %@%@ **<reset> <faint>(%03d ms)<reset>",
   color,
   [name uppercaseString],
   status,
   message != nil ? [@": " stringByAppendingString:message] : @"",
   (int)(duration * 1000)];
}

- (void)beginXcodebuild:(NSDictionary *)event
{
  [_reportWriter printLine:@"xcodebuild <bold>%@<reset> <underline>%@<reset>",
   event[kReporter_BeginXcodebuild_CommandKey],
   event[kReporter_BeginXcodebuild_TitleKey]];
  [_reportWriter increaseIndent];
}

- (void)endXcodebuild:(NSDictionary *)event
{
  [_reportWriter decreaseIndent];

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

  [_reportWriter printNewline];
}

- (void)beginBuildTarget:(NSDictionary *)event
{
  [_reportWriter printLine:@"<bold>%@<reset> / <bold>%@<reset> (%@)",
   event[kReporter_BeginBuildTarget_ProjectKey],
   event[kReporter_BeginBuildTarget_TargetKey],
   event[kReporter_BeginBuildTarget_ConfigurationKey]];
  [_reportWriter increaseIndent];
}

- (void)endBuildTarget:(NSDictionary *)event
{
  [_reportWriter printLine:@"<bold>%lu errored, %lu warning %@<reset>",
   [event[kReporter_EndBuildCommand_TotalNumberOfErrors] unsignedIntegerValue],
   [event[kReporter_EndBuildCommand_TotalNumberOfWarnings] unsignedIntegerValue],
   [self formattedTestDuration:[event[kReporter_EndBuildCommand_DurationKey] doubleValue] withColor:NO]
   ];
  [_reportWriter decreaseIndent];
  [_reportWriter printNewline];
}

- (void)beginBuildCommand:(NSDictionary *)event
{
  [_reportWriter updateLine:@"%@ %@",
   [self emptyIndicatorString],
   [self condensedBuildCommandTitle:event[kReporter_BeginBuildCommand_TitleKey]]];
  _currentBuildCommandEvent = event;
}

- (void)endBuildCommand:(NSDictionary *)event
{
  BOOL succeeded = [event[kReporter_EndBuildCommand_SucceededKey] boolValue];
  NSString *outputText = [event[kReporter_EndBuildCommand_EmittedOutputTextKey]
                          stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  NSString *indicator = nil;
  if (succeeded) {
    if ([event[kReporter_EndBuildCommand_TotalNumberOfWarnings] unsignedIntegerValue] > 0) {
      indicator = [self warningIndicatorString];
    } else {
      indicator = [self passIndicatorString];
    }
  } else {
    indicator = [self failIndicatorString];
  }

  [_reportWriter updateLine:@"%@ %@ %@",
   indicator,
   [self condensedBuildCommandTitle:event[kReporter_EndBuildCommand_TitleKey]],
   [self formattedTestDuration:[event[kReporter_EndBuildCommand_DurationKey] doubleValue] withColor:YES]];
  [_reportWriter printNewline];

  BOOL showInfo = !succeeded || (outputText.length > 0);

  if (showInfo) {
    [self printDivider];
    [_reportWriter disableIndent];

    // If the command failed, it's always interesting to see the full command being run.
    if (!succeeded) {
      [_reportWriter printLine:@"<faint>%@<reset>", _currentBuildCommandEvent[kReporter_BeginBuildCommand_CommandKey]];
    }

    if (outputText.length > 0) {
      [_reportWriter printLine:@"<faint>%@<reset>", outputText];
    }

    [_reportWriter enableIndent];
    [self printDivider];
  }

  if (!succeeded) {
    NSString *body = [NSString stringWithFormat:@"%@\n%@",
                      _currentBuildCommandEvent[kReporter_BeginBuildCommand_CommandKey], outputText];

    [_failedBuildEvents addObject:@{@"title":event[kReporter_EndBuildCommand_TitleKey], @"body":body}];
  }

  _currentBuildCommandEvent = event;
}

- (void)beginOcunit:(NSDictionary *)event
{
  NSString *titleString = nil;

  if (event[kReporter_BeginOCUnit_BundleNameKey]) {
    titleString = event[kReporter_BeginOCUnit_BundleNameKey];
  } else {
    // The bundle name won't be available if we fail to load the build settings
    // for this test target.  Fall back to just target name.
    titleString = event[kReporter_BeginOCUnit_TargetNameKey];
  }

  // Some attributes may be unset if we're unable to query build settings for
  // the test bundle.
  NSMutableArray *attributes = [NSMutableArray array];

  if (event[kReporter_BeginOCUnit_SDKNameKey]) {
    [attributes addObject:event[kReporter_BeginOCUnit_SDKNameKey]];
  }

  if (event[kReporter_BeginOCUnit_DeviceNameKey]) {
    [attributes addObject:event[kReporter_BeginOCUnit_DeviceNameKey]];
  }

  if (event[kReporter_BeginOCUnit_TestTypeKey]) {
    [attributes addObject:event[kReporter_BeginOCUnit_TestTypeKey]];
  }

  NSString *attributesString = nil;

  if ([attributes count] > 0) {
    attributesString = [NSString stringWithFormat:@"(%@)", [attributes componentsJoinedByString:@", "]];
  } else {
    attributesString = @"";
  }

  [_reportWriter printLine:@"<bold>run-test<reset> <underline>%@<reset> %@", titleString, attributesString];
  _currentBundle = event[kReporter_BeginOCUnit_BundleNameKey];
  [_reportWriter increaseIndent];
}

- (void)endOcunit:(NSDictionary *)event
{
  [_reportWriter decreaseIndent];

  NSString *message = event[kReporter_EndOCUnit_MessageKey];

  if (![message isEqual:[NSNull null]]) {
    [self printDivider];
    [_reportWriter disableIndent];

    [_reportWriter printString:@"<faint>%@<reset>", message];

    if (![message hasSuffix:@"\n"]) {
      [_reportWriter printNewline];
    }

    if (![event[kReporter_EndOCUnit_SucceededKey] boolValue]) {
      [_failedOcunitEvents addObject:event];
      [_resultCounter suiteBegin];
      [_resultCounter testErrored];
      [_resultCounter suiteEnd];
    }

    [_reportWriter enableIndent];
    [self printDivider];
  }

  [_reportWriter printNewline];
}

- (void)beginTestSuite:(NSDictionary *)event
{
  NSString *suite = event[kReporter_BeginTestSuite_SuiteKey];
  [_resultCounter suiteBegin];

  if (![suite isEqualToString:kReporter_TestSuite_TopLevelSuiteName] && ![suite hasSuffix:@".octest(Tests)"]) {
    if ([suite hasPrefix:@"/"]) {
      suite = [suite lastPathComponent];
    }

    [_reportWriter printLine:@"<bold>suite<reset> <underline>%@<reset>", suite];
    [_reportWriter increaseIndent];
  }
}

- (void)endTestSuite:(NSDictionary *)event
{
  NSString *suite = event[kReporter_EndTestSuite_SuiteKey];
  [_resultCounter suiteEnd];

  if (![suite isEqualToString:kReporter_TestSuite_TopLevelSuiteName] && ![suite hasSuffix:@".octest(Tests)"]) {
    [_reportWriter printLine:@"<bold>%lu passed, %lu failed, %lu errored, %lu total %@<reset>",
      [_resultCounter suitePassed],
      [_resultCounter suiteFailed],
      [_resultCounter suiteErrored],
      [_resultCounter suiteTotal],
     [self formattedTestDuration:[event[kReporter_EndTestSuite_TotalDurationKey] doubleValue] withColor:NO]
     ];
    [_reportWriter decreaseIndent];
  } else if ([suite isEqualToString:kReporter_TestSuite_TopLevelSuiteName] && [_resultCounter suiteTotal] > 0) {
    [_reportWriter printLine:@"<bold>%lu passed, %lu failed, %lu errored, %lu total %@<reset>",
      [_resultCounter suitePassed],
      [_resultCounter suiteFailed],
      [_resultCounter suiteErrored],
      [_resultCounter suiteTotal],
     [self formattedTestDuration:[event[kReporter_EndTestSuite_TotalDurationKey] doubleValue] withColor:NO]
     ];
  }
}

- (void)beginTest:(NSDictionary *)event
{
  [_reportWriter updateLine:@"%@ %@", [self emptyIndicatorString], event[kReporter_BeginTest_TestKey]];
  _testHadOutput = NO;
}

- (void)testOutput:(NSDictionary *)event {
  if ([event[kReporter_TestOutput_OutputKey] length] == 0) {
    return;
  }

  if (!_testHadOutput) {
    [_reportWriter printNewline];
    [self printDivider];
  }

  [_reportWriter disableIndent];
  [_reportWriter printString:@"<faint>%@<reset>", event[kReporter_TestOutput_OutputKey]];
  [_reportWriter enableIndent];

  _testHadOutput = YES;
  _testOutputEndsInNewline = [event[kReporter_TestOutput_OutputKey] hasSuffix:@"\n"];
}

- (void)beginStatus:(NSDictionary *)event
{
  NSAssert(_currentStatusEvent == nil,
           @"An earlier begin-status event never followed with a end-status event.");

  _currentStatusEvent = event;

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

  double duration = ([event[kReporter_TimestampKey] doubleValue] -
                     [_currentStatusEvent[kReporter_TimestampKey] doubleValue]);

  NSMutableString *line = [NSMutableString string];
  [line appendFormat:@"[%@] ", event[kReporter_EndStatus_LevelKey]];
  [line appendString:event[kReporter_EndStatus_MessageKey]];
  if (duration > 0) {
    [line appendFormat:@" %@", [self formattedTestDuration:duration withColor:NO]];
  }

  [_reportWriter updateLine:@"%@", line];
  [_reportWriter printNewline];

  _currentStatusEvent = nil;
}

- (NSString *)formattedTestDuration:(double)duration withColor:(BOOL)withColor
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
  NSString *result = event[kReporter_EndTest_ResultKey];

  if ([result isEqualToString:@"success"]) {
    indicator = [self passIndicatorString];
    [_resultCounter testPassed];
  } else if ([result isEqualToString:@"failure"]) {
    indicator = [self failIndicatorString];
    [_resultCounter testFailed];
  } else {
    indicator = [self errorIndicatorString];
    [_resultCounter testErrored];
  }

  if (showInfo) {
    if (!_testHadOutput) {
      [_reportWriter printNewline];
      [self printDivider];
    }

    [_reportWriter disableIndent];

    // Make sure the exception or the divider aren't drawn on the same line
    // as the previous output.
    if (_testHadOutput && !_testOutputEndsInNewline) {
      [_reportWriter printNewline];
    }

    // Show first exception, if any.
    NSArray *exceptions = event[kReporter_EndTest_ExceptionsKey];
    if ([exceptions count] > 0) {
      NSDictionary *exception = exceptions[0];
      NSString *filePath = exception[kReporter_EndTest_Exception_FilePathInProjectKey];
      int lineNumber = [exception[kReporter_EndTest_Exception_LineNumberKey] intValue];

      [_reportWriter printLine:@"<faint>%@:%d: %@:<reset>",
       filePath,
       lineNumber,
       exception[kReporter_EndTest_Exception_ReasonKey]];

      if ([[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:nil]) {
        NSString *context = [TextReporter getContext:filePath errorLine:lineNumber];
        [_reportWriter printLine:@"<faint>%@<reset>", context];
      }
    }

    [_reportWriter enableIndent];
    [self printDividerWithDownLine:YES];
  } else if (_testHadOutput) {
    [_reportWriter disableIndent];
    if (!_testOutputEndsInNewline) {
      [_reportWriter printNewline];
    }
    [_reportWriter enableIndent];
    [self printDividerWithDownLine:YES];
  }

  NSMutableString *resultLine = [NSMutableString stringWithFormat:@"%@ %@ %@",
                                 indicator,
                                 event[kReporter_EndTest_TestKey],
                                 [self formattedTestDuration:[event[kReporter_EndTest_TotalDurationKey] doubleValue] withColor:YES]
                                 ];

  // If the test failed, add a number linking it to the failure summary.
  if (!succeeded) {
    [resultLine appendFormat:@" (%ld)", [_failedTests count]];

    // Add the test information to the list of failed tests for printing later.
    [_failedTests addObject:@{@"bundle": _currentBundle, kReporter_Event_Key: event}];
  }

  [_reportWriter updateLine:@"%@", resultLine];
  [_reportWriter printNewline];
}

- (void)analyzerResult:(NSDictionary *)event
{
  [_analyzerWarnings addObject:event];
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
        NSString *lineStr = [lines[lineNo] description];
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

- (instancetype)init
{
  if (self = [super init]) {
    self.isPretty = YES;
    self.canOverwrite = YES;
  }
  return self;
}

@end

@implementation NoOverwritePrettyTextReporter

- (instancetype)init
{
  if (self = [super init]) {
    self.isPretty = YES;
  }
  return self;
}

@end

@implementation PlainTextReporter

- (instancetype)init
{
  if (self = [super init]) {
    self.isPretty = NO;
  }
  return self;
}

@end
