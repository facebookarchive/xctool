
#import "Reporter+Testing.h"

@interface FakeFileHandle : NSObject
{
  NSMutableData *_dataWritten;
}

- (NSData *)dataWritten;
- (int)fileDescriptor;
- (void)synchronizeFile;

@end

@implementation FakeFileHandle

- (id)init
{
  if (self = [super init]) {
    _dataWritten = [[NSMutableData alloc] initWithCapacity:0];
  }
  return self;
}

- (void)dealloc
{
  [_dataWritten release];
  [super dealloc];
}

- (void)writeData:(NSData *)data
{
  [_dataWritten appendData:data];
}

- (NSData *)dataWritten
{
  return _dataWritten;
}

- (int)fileDescriptor {
  // Not true, but this will appease some callers.
  return STDOUT_FILENO;
}

- (void)synchronizeFile
{
}

@end

@implementation Reporter (Testing)

+ (NSData *)outputDataWithEventsFromFile:(NSString *)path
                                 options:(Options *)options
{
  Reporter *reporter = [[self alloc] init];
  [reporter setOutputPath:@"-"];
  [reporter setOptions:options];

  FakeFileHandle *fakeFileHandle = [[FakeFileHandle alloc] init];

  [reporter openWithStandardOutput:(NSFileHandle *)fakeFileHandle error:nil];

  NSString *pathContents = [NSString stringWithContentsOfFile:path
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
  NSArray *lines = [pathContents componentsSeparatedByCharactersInSet:
                    [NSCharacterSet newlineCharacterSet]];
  for (NSString *line in lines) {
    if ([line length] == 0) {
      break;
    }

    [reporter handleEvent:
     [NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding]
                                     options:0
                                       error:nil]];
  }

  [reporter close];
  NSData *outputData = [[fakeFileHandle dataWritten] retain];

  [reporter release];
  [fakeFileHandle release];

  return [outputData autorelease];
}

@end

