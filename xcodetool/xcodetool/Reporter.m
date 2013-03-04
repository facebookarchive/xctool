
#import "Reporter.h"
#import "RawReporter.h"
#import "TextReporter.h"
#import "PJSONKit.h"

@implementation Reporter

+ (Reporter *)reporterWithName:(NSString *)name outputPath:(NSString *)outputPath
{
  NSDictionary *reporters = @{@"raw": [RawReporter class],
                              @"pretty": [PrettyTextReporter class],
                              @"plain": [PlainTextReporter class],
                              };
  
  Class reporterClass = reporters[name];
  return [[[reporterClass alloc] initWithOutputPath:outputPath] autorelease];
}

- (id)initWithOutputPath:(NSString *)outputPath
{
  if (self = [super init]) {
    self.outputPath = outputPath;
  }
  return self;
}

- (void)dealloc
{
  [_outputHandle release];
  [super dealloc];
}

- (void)setupOutputHandleWithStandardOutput:(NSFileHandle *)standardOutput
{
  if ([self.outputPath isEqualToString:@"-"]) {
    _outputHandle = [standardOutput retain];
  } else {
    [[NSFileManager defaultManager] createFileAtPath:self.outputPath contents:nil attributes:nil];
    _outputHandle = [[NSFileHandle fileHandleForWritingAtPath:self.outputPath] retain];
  }
}

- (void)handleEvent:(NSString *)eventLine
{
  NSError *error = nil;
  NSDictionary *eventDict = [eventLine XT_objectFromJSONStringWithParseOptions:XT_JKParseOptionNone error:&error];
  
  if (error != nil) {
    NSLog(@"ERROR: Can't parse event '%@': %@", eventLine, [error localizedFailureReason]);
    abort();
  }
  
  NSString *event = eventDict[@"event"];
  NSMutableString *selectorName = [NSMutableString string];
  
  int i = 0;
  for (NSString *part in [event componentsSeparatedByString:@"-"]) {
    if (i++ == 0) {
      [selectorName appendString:[part lowercaseString]];
    } else {
      [selectorName appendString:[[part lowercaseString] capitalizedString]];
    }
  }
  [selectorName appendString:@":"];
  
  SEL sel = sel_registerName([selectorName UTF8String]);
  [self performSelector:sel withObject:eventDict];
}

- (void)beginBuildTarget:(NSDictionary *)event {}
- (void)endBuildTarget:(NSDictionary *)event {}
- (void)beginBuildCommand:(NSDictionary *)event {}
- (void)endBuildCommand:(NSDictionary *)event {}
- (void)beginXcodebuild:(NSDictionary *)event {}
- (void)endXcodebuild:(NSDictionary *)event {}
- (void)beginOctest:(NSDictionary *)event {}
- (void)endOctest:(NSDictionary *)event {}
- (void)beginTestSuite:(NSDictionary *)event {}
- (void)endTestSuite:(NSDictionary *)event {}
- (void)beginTest:(NSDictionary *)event {}
- (void)endTest:(NSDictionary *)event {}
- (void)testOutput:(NSDictionary *)event {}



@end
