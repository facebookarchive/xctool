#import "JSONCompilationDatabaseReporter.h"

#import "ReporterEvents.h"

@interface NSString (Strip)

- (NSString *)strip;
- (NSTextCheckingResult *)firstMatch:(NSArray *)prioritizedRegEx;

@end

@implementation NSString (Strip)

- (NSString *)strip
{
  return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (NSTextCheckingResult *)firstMatch:(NSArray *)prioritizedRegExString
{
  NSError *error = nil;
  for (NSString *regexString in prioritizedRegExString) {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexString
                                                                           options:0
                                                                             error:&error];
    NSTextCheckingResult *match = [regex firstMatchInString:self
                                                    options:0
                                                      range:NSMakeRange(0, [self length])];
    if (match) {
      return match;
    }
  }
  return nil;
}

@end


@implementation JSONCompilationDatabaseReporter

- (id)init
{
  self = [super init];
  if (self) {
    _compiles = [[NSMutableArray alloc] init];
    _precompiles = [[NSMutableArray alloc] init];
    _currentBuildCommand = nil;
  }
  return self;
}

- (void)dealloc
{
  [_precompiles release];
  [_compiles release];
  [super dealloc];
}

- (void)collectEvent:(NSDictionary *)event
{
  NSString *title = event[kReporter_BeginBuildCommand_TitleKey];
  if ([title hasPrefix:@"Precompile"]) {
    [_precompiles addObject:event];
  }
  if ([title hasPrefix:@"Compile"]) {
    [_compiles addObject:event];
  }
}

- (void)beginBuildCommand:(NSDictionary *)event
{
  _currentBuildCommand = [event retain];
}

- (void)endBuildCommand:(NSDictionary *)event
{
  BOOL succeeded = [event[kReporter_EndBuildCommand_SucceededKey] boolValue];
  if (succeeded && _currentBuildCommand) {
    [self collectEvent:_currentBuildCommand];
  }

  [_currentBuildCommand release];
  _currentBuildCommand = nil;
}

- (void)didFinishReporting
{
  NSDictionary *precompilesLocalMapping = [self precompilesLocalMapping:_precompiles];
  NSMutableArray *compilationDatabase = [[NSMutableArray alloc] init];
  for (NSDictionary *event in _compiles) {
    NSDictionary *compile = [self convertCompileDictionary:event withPrecompilesLocalMapping:precompilesLocalMapping];
    if (compile) {
      [compilationDatabase addObject:compile];
    }
  }

  NSError *error = nil;
  NSData *data =  [NSJSONSerialization dataWithJSONObject:compilationDatabase
                                                  options:NSJSONWritingPrettyPrinted
                                                    error:&error];
  NSAssert(error == nil, @"Failed while trying to encode as JSON: %@", error);

  [_outputHandle writeData:data];
  [_outputHandle writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];

  [compilationDatabase release];
  compilationDatabase = nil;
}

- (NSDictionary *)convertCompileDictionary:(NSDictionary *)event withPrecompilesLocalMapping:(NSDictionary *)precompilesMapping
{
  NSString *eventBuildCommand = event[kReporter_BeginBuildCommand_CommandKey];
  NSArray *eventBuildcommands = [eventBuildCommand componentsSeparatedByString:@"\n"];
  NSString *rawWorkingDirectory = [eventBuildcommands[1] strip];
  NSString *rawCompilerCommand = nil;
  // We know the first line is event tile, the second one is to change to the working directory
  // so we start with the third line, discard lines of setting env variables, then it's compiler command
  for (int i = 2; i < [eventBuildcommands count]; i++) {
    NSString *currentCommand = [eventBuildcommands[i] strip];
    if (![currentCommand hasPrefix:@"setenv"]) {
      rawCompilerCommand = currentCommand;
      break;
    }
  }
  if (!rawCompilerCommand) {
    return nil;
  }

  NSTextCheckingResult *workingDirectoryMatch = [rawWorkingDirectory firstMatch:@[@"^cd \"(.+)\"", @"^cd (.+)"]];
  NSTextCheckingResult *sourceFileMatch = [rawCompilerCommand firstMatch:@[@"-c \"(.+?)\"", @" -c (.+?) -o"]];
  NSTextCheckingResult *pchMatch = [rawCompilerCommand firstMatch:@[@"-include \"(.+?\\.pch)\"", @"-include (.+?\\.pch)"]];

  if (sourceFileMatch && workingDirectoryMatch && pchMatch) {
    NSRange cachedPrecompilePathRange = [pchMatch rangeAtIndex:1];
    NSString *cachedPrecompiledPath = [rawCompilerCommand substringWithRange:cachedPrecompilePathRange];
    NSString *localPrecompilePath = precompilesMapping[cachedPrecompiledPath];
    if (localPrecompilePath) {
      NSMutableDictionary *compile = [[NSMutableDictionary alloc] init];
      compile[@"directory"] = [rawWorkingDirectory substringWithRange:[workingDirectoryMatch rangeAtIndex:1]];
      compile[@"command"] = [rawCompilerCommand stringByReplacingCharactersInRange:cachedPrecompilePathRange withString:localPrecompilePath];
      compile[@"file"] = [rawCompilerCommand substringWithRange:[sourceFileMatch rangeAtIndex:1]];
      return [compile autorelease];
    }
  }
  return nil;
}

- (NSDictionary *)precompilesLocalMapping:(NSArray *)precompiles
{
  NSMutableDictionary *localMapping = [[NSMutableDictionary alloc] init];
  for (NSDictionary *event in precompiles) {
    NSString *command = event[kReporter_BeginBuildCommand_CommandKey];
    NSArray *commands = [command componentsSeparatedByString:@"\n"];
    NSString *precompileTitle = [commands[0] strip];
    NSString *workingDirectory = [commands[1] strip];

    NSTextCheckingResult *precompileTitleMatch =
    [precompileTitle firstMatch:@[@"^ProcessPCH(\\+\\+)? \"(.+)(\\.pch\\.pth|\\.pch\\.pch)\" \"(.+)\\.pch\"",
     @"^ProcessPCH(\\+\\+)? (.+)(\\.pch\\.pth|\\.pch\\.pch) (.+)\\.pch"]];
    NSTextCheckingResult *workingDirectoryMatch = [workingDirectory firstMatch:@[@"^cd \"(.+)\"", @"^cd (.+)"]];

    if (precompileTitleMatch && workingDirectoryMatch) {
      NSRange firstHalfRange = [precompileTitleMatch rangeAtIndex:2];
      NSRange secondHalfRange = [precompileTitleMatch rangeAtIndex:4];
      NSString *cachedPath = [NSString stringWithFormat:@"%@.pch", [precompileTitle substringWithRange:firstHalfRange]];
      NSString *localPath = [NSString stringWithFormat:@"%@/%@.pch",
                             [workingDirectory substringWithRange:[workingDirectoryMatch rangeAtIndex:1]],
                             [precompileTitle substringWithRange:secondHalfRange]];
      localMapping[cachedPath] = localPath;
    }

  }
  return [localMapping autorelease];
}

@end
