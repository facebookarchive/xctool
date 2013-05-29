
#import "FakeFileHandle.h"

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
