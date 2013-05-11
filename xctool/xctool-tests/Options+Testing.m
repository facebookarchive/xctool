
#import "Options+Testing.h"

#import "XcodeSubjectInfo.h"
#import "XCToolUtil.h"

@interface FakeXcodeSubjectInfo : XcodeSubjectInfo
{
}

@property (nonatomic, retain) NSDictionary *fakeBuildSettings;

@end

@implementation FakeXcodeSubjectInfo

- (void)dealloc
{
  [_fakeBuildSettings release];
  [super dealloc];
}

- (NSDictionary *)buildSettingsForFirstBuildable
{
  return _fakeBuildSettings;
}

@end

@implementation Options (Testing)

+ (Options *)optionsFrom:(NSArray *)arguments
{
  Options *options = [[[Options alloc] init] autorelease];

  NSString *errorMessage = nil;
  [options consumeArguments:[NSMutableArray arrayWithArray:arguments]
               errorMessage:&errorMessage];

  if (errorMessage != nil) {
    [NSException raise:NSGenericException
                format:@"Failed to parse options: %@", errorMessage];
  }

  return options;
}

- (Options *)assertReporterOptionsValidate
{
  NSString *errorMessage = nil;
  BOOL valid = [self validateReporterOptions:&errorMessage];

  if (!valid) {
    [NSException raise:NSGenericException
                format:@"Failed to validate reporter options: %@", errorMessage];
  }

  return self;
}

- (void)assertReporterOptionsFailToValidateWithError:(NSString *)message
{
  NSString *errorMessage = nil;
  BOOL valid = [self validateReporterOptions:&errorMessage];

  if (valid) {
    [NSException raise:NSGenericException
                format:@"Expected reporter validation to failed, but passed."];
  } else if (!valid && ![message isEqualToString:errorMessage]) {
    [NSException raise:NSGenericException
                format:
     @"Expected reporter validation to fail with message '%@' but "
     @"instead failed with '%@'", message, errorMessage];
  }
}


- (void)assertOptionsFailToValidateWithError:(NSString *)message
{
  NSString *errorMessage = nil;
  BOOL valid = [self validateOptions:&errorMessage
                    xcodeSubjectInfo:nil
                             options:self];

  if (valid) {
    [NSException raise:NSGenericException
                format:@"Expected validation to failed, but passed."];
  } else if (!valid && ![message isEqualToString:errorMessage]) {
    [NSException raise:NSGenericException
                format:
     @"Expected validation to fail with message '%@' but instead failed "
     @"with '%@'", message, errorMessage];
  }
}

- (void)assertOptionsFailToValidateWithError:(NSString *)message
                   withBuildSettingsFromFile:(NSString *)path
{
  NSString *contents = [NSString stringWithContentsOfFile:path
                                                 encoding:NSUTF8StringEncoding
                                                    error:nil];
  if (contents == nil) {
    [NSException raise:NSGenericException
                format:@"Failed to read file from: %@", path];
  }

  FakeXcodeSubjectInfo *subjectInfo = [[[FakeXcodeSubjectInfo alloc] init] autorelease];
  [subjectInfo setFakeBuildSettings:BuildSettingsFromOutput(contents)];

  NSString *errorMessage = nil;
  BOOL valid = [self validateOptions:&errorMessage
                    xcodeSubjectInfo:subjectInfo
                             options:self];

  if (valid) {
    [NSException raise:NSGenericException
                format:@"Expected validation to failed, but passed."];
  } else if (!valid && ![message isEqualToString:errorMessage]) {
    [NSException raise:NSGenericException
                format:
     @"Expected validation to fail with message '%@' but instead "
     @"failed with '%@'", message, errorMessage];
  }
}

- (Options *)assertOptionsValidateWithBuildSettingsFromFile:(NSString *)path
{
  [self assertReporterOptionsValidate];
  
  NSString *contents = [NSString stringWithContentsOfFile:path
                                                 encoding:NSUTF8StringEncoding
                                                    error:nil];
  if (contents == nil) {
    [NSException raise:NSGenericException
                format:@"Failed to read file from: %@", path];
  }

  FakeXcodeSubjectInfo *subjectInfo = [[[FakeXcodeSubjectInfo alloc] init] autorelease];
  [subjectInfo setFakeBuildSettings:BuildSettingsFromOutput(contents)];

  NSString *errorMessage = nil;
  BOOL valid = [self validateOptions:&errorMessage
                    xcodeSubjectInfo:subjectInfo
                             options:self];

  if (!valid) {
    [NSException raise:NSGenericException
                format:
     @"Expected validation to pass but failed with message '%@'", errorMessage];
  }

  return self;
}

@end
