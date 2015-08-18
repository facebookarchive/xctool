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

@interface JSONCompilationDatabaseReporter ()
@property (nonatomic, copy) NSMutableArray *compiles;
@property (nonatomic, copy) NSDictionary *currentBuildCommand;
@property (nonatomic, copy) NSMutableArray *precompiles;
@end

@implementation JSONCompilationDatabaseReporter

- (instancetype)init
{
  self = [super init];
  if (self) {
    _compiles = [[NSMutableArray alloc] init];
    _currentBuildCommand = nil;
    _precompiles = [[NSMutableArray alloc] init];
  }
  return self;
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
  _currentBuildCommand = event;
}

- (void)endBuildCommand:(NSDictionary *)event
{
  BOOL succeeded = [event[kReporter_EndBuildCommand_SucceededKey] boolValue];
  if (succeeded && _currentBuildCommand) {
    [self collectEvent:_currentBuildCommand];
  }

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
    // on Xcode 5.1, setting env variables is changed from setenv to export
    if (![currentCommand hasPrefix:@"setenv"] && ![currentCommand hasPrefix:@"export"]) {
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

  if (sourceFileMatch && workingDirectoryMatch) {
    NSMutableDictionary *compile = [[NSMutableDictionary alloc] init];
    compile[@"file"] = [rawCompilerCommand substringWithRange:[sourceFileMatch rangeAtIndex:1]];
    compile[@"directory"] = [rawWorkingDirectory substringWithRange:[workingDirectoryMatch rangeAtIndex:1]];
    NSString *convertedCompilerCommand = nil;
    if (pchMatch) {
      NSRange cachedPrecompilePathRange = [pchMatch rangeAtIndex:1];
      NSString *cachedPrecompiledPath = [rawCompilerCommand substringWithRange:cachedPrecompilePathRange];
      NSString *localPrecompilePath = precompilesMapping[cachedPrecompiledPath];
      if (localPrecompilePath) {
        convertedCompilerCommand = [rawCompilerCommand stringByReplacingCharactersInRange:cachedPrecompilePathRange withString:localPrecompilePath];
      } else {
        convertedCompilerCommand = rawCompilerCommand;
      }
    } else {
      convertedCompilerCommand = rawCompilerCommand;
    }
    compile[@"command"] = convertedCompilerCommand;
    return compile;
  }
  return nil;
}

- (NSDictionary *)precompilesLocalMapping:(NSArray *)precompiles
{
  NSMutableDictionary *localMapping = [[NSMutableDictionary alloc] init];
  for (NSDictionary *event in precompiles) {
    NSString *command = event[kReporter_BeginBuildCommand_CommandKey];
    NSArray *commands = [command componentsSeparatedByString:@"\n"];
    NSString *precompileCommand = [commands[0] strip];
    NSString *workingDirectoryCommand = [commands[1] strip];

    NSTextCheckingResult *precompileMatch =
    [precompileCommand firstMatch:@[@"^ProcessPCH(\\+\\+)? \"(.+)(\\.pch\\.pth|\\.pch\\.pch)\" \"(.+)\\.pch\"",
     @"^ProcessPCH(\\+\\+)? (.+)(\\.pch\\.pth|\\.pch\\.pch) (.+)\\.pch"]];
    NSTextCheckingResult *workingDirectoryMatch = [workingDirectoryCommand firstMatch:@[@"^cd \"(.+)\"", @"^cd (.+)"]];

    if (precompileMatch && workingDirectoryMatch) {
      NSString *cachedPchPath = [precompileCommand substringWithRange:[precompileMatch rangeAtIndex:2]];
      NSString *sourcePchName = [precompileCommand substringWithRange:[precompileMatch rangeAtIndex:4]];
      NSString *workingDir = [workingDirectoryCommand substringWithRange:[workingDirectoryMatch rangeAtIndex:1]];

      cachedPchPath = [cachedPchPath stringByAppendingPathExtension:@"pch"];
      if (![cachedPchPath hasPrefix:@"/"]) {
        cachedPchPath = [workingDir stringByAppendingPathComponent:cachedPchPath];
      }
      NSString *localPath = [NSString stringWithFormat:@"%@/%@.pch", workingDir, sourcePchName];
      localMapping[cachedPchPath] = localPath;
    }

  }
  return localMapping;
}

@end
