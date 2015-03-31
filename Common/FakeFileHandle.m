
#import "FakeFileHandle.h"

@implementation FakeFileHandle

- (instancetype)init
{
  if (self = [super init]) {
    _dataWritten = [[NSMutableData alloc] initWithCapacity:0];
  }
  return self;
}

- (void)writeData:(NSData *)data
{
  [_dataWritten appendData:data];
}

- (NSData *)dataWritten
{
  return _dataWritten;
}

- (NSString *)stringWritten
{
  return [[NSString alloc] initWithData:_dataWritten
                                encoding:NSUTF8StringEncoding];
}

- (int)fileDescriptor {
  // Not true, but this will appease some callers.
  return STDOUT_FILENO;
}

- (void)synchronizeFile
{
}

@end
