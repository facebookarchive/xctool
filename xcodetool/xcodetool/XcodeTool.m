
#import "XcodeTool.h"
#import "Functions.h"
#import "NSFileHandle+Print.h"
#import "ApplicationTestRunner.h"
#import "LogicTestRunner.h"
#import "RawReporter.h"
#import "TextReporter.h"
#import "PJSONKit.h"
#import "XcodeSubjectInfo.h"
#import "Action.h"
#import "Options.h"

@implementation XcodeTool

- (id)init
{
  if (self = [super init]) {
    _exitStatus = 0;
  }
  return self;
}

- (void)printUsage
{
  [_standardError printString:@"usage: xcodetool [BASE OPTIONS] [ACTION [ACTION ARGUMENTS]] ...\n\n"];
  
  [_standardError printString:@"Examples:\n"];
  for (NSArray *verbAndClass in [Options actionClasses]) {
    NSString *verb = verbAndClass[0];
    NSArray *options = [verbAndClass[1] performSelector:@selector(options)];
    
    NSMutableString *buffer = [NSMutableString string];
    
    for (NSDictionary *option in options) {
      if (option[kActionOptionParamName]) {
        [buffer appendFormat:@" [-%@ %@]", option[kActionOptionName], option[kActionOptionParamName]];
      } else {
        [buffer appendFormat:@" [-%@]", option[kActionOptionName]];
      }
    }
    
    [_standardError printString:@"    xcodetool [BASE OPTIONS] %@%@", verb, buffer];
    [_standardError printString:@"\n"];
  }
  
  [_standardError printString:@"\n"];
  
  [_standardError printString:@"Base Options:\n"];
  [_standardError printString:@"%@", [Options actionUsage]];
  
  for (NSArray *verbAndClass in [Options actionClasses]) {
    NSString *verb = verbAndClass[0];
    NSString *actionUsage = [verbAndClass[1] actionUsage];
    
    if (actionUsage.length > 0) {
      [_standardError printString:@"\n"];
      [_standardError printString:@"Options for '%@' action:\n", verb];
      [_standardError printString:@"%@", actionUsage];
    }
  }
  
  [_standardError printString:@"\n"];
}

- (void)run
{
  Options *options = [[[Options alloc] init] autorelease];
  XcodeSubjectInfo *xcodeSubjectInfo = [[[XcodeSubjectInfo alloc] init] autorelease];
  
  NSString *errorMessage = nil;
  
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm isReadableFileAtPath:@".xcodetool-args"]) {
    NSError *readError = nil;
    NSString *argumentsString = [NSString stringWithContentsOfFile:@".xcodetool-args"
                                                          encoding:NSUTF8StringEncoding
                                                             error:&readError];
    if (readError) {
      [_standardError printString:@"ERROR: Cannot read '.xcodetool-args' file: %@\n", [readError localizedFailureReason]];
      _exitStatus = 1;
      return;
    }
    
    NSError *JSONError = nil;
    NSArray *argumentsList = [argumentsString XT_objectFromJSONStringWithParseOptions:XT_JKParseOptionComments error:&JSONError];
    
    if (JSONError) {
      [_standardError printString:@"ERROR: couldn't parse json: %@: %@\n", argumentsString, [JSONError localizedDescription]];
      _exitStatus = 1;
      return;
    }
    
    if (![options consumeArguments:[NSMutableArray arrayWithArray:argumentsList] errorMessage:&errorMessage]) {
      [_standardError printString:@"ERROR: %@\n", errorMessage];
      _exitStatus = 1;
      return;
    }
  }

  if (![options consumeArguments:[NSMutableArray arrayWithArray:self.arguments] errorMessage:&errorMessage]) {
    [_standardError printString:@"ERROR: %@\n", errorMessage];
    [self printUsage];
    _exitStatus = 1;
    return;
  }
  
  if (options.showHelp) {
    [self printUsage];
    _exitStatus = 1;
    return;
  }
  
  if (![options validateOptions:&errorMessage xcodeSubjectInfo:xcodeSubjectInfo options:options]) {
    [_standardError printString:@"ERROR: %@\n\n", errorMessage];
    [self printUsage];
    _exitStatus = 1;
    return;
  }
  
  for (Reporter *reporter in options.reporters) {
    [reporter setupOutputHandleWithStandardOutput:_standardOutput];
  }
  
  for (Action *action in options.actions) {
    if (![action performActionWithOptions:options xcodeSubjectInfo:xcodeSubjectInfo]) {
      _exitStatus = 1;
    }
  }
  
  for (Reporter *reporter in options.reporters) {
    @try {
      [[reporter outputHandle] synchronizeFile];
    } @catch (NSException *ex) {
    }
  }
}


@end
