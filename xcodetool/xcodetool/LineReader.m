
#import "LineReader.h"

@implementation LineReader

- (id)initWithFileHandle:(NSFileHandle *)fileHandle
{
  if (self = [super init]) {
    _fileHandle = [fileHandle retain];
    _buffer = [[NSMutableString alloc] initWithCapacity:0];
  }
  return self;
}

- (void)dealloc
{
  [_fileHandle release];
  [_buffer release];
  [super dealloc];
}

- (void)processBuffer
{
  NSUInteger offset = 0;
  
  for (;;) {
    NSRange newlineRange = [_buffer rangeOfString:@"\n"
                                          options:0
                                            range:NSMakeRange(offset, [_buffer length] - offset)];
    
    if (newlineRange.length == 0) {
      break;
    } else {
      NSString *line = [_buffer substringWithRange:NSMakeRange(offset, newlineRange.location - offset)];
      self.didReadLineBlock(line);
      offset = newlineRange.location + 1;
    }
  }

  [_buffer replaceCharactersInRange:NSMakeRange(0, offset) withString:@""];
}

- (void)appendDataToBuffer:(NSData *)data
{
  [_buffer appendString:[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]];
}

- (void)dataAvailableNotification:(NSNotification *)notification
{
  NSData *data = [_fileHandle availableData];
  
  if (data.length > 0) {
    [self appendDataToBuffer:data];
    [self processBuffer];
  }
  
  [_fileHandle waitForDataInBackgroundAndNotify];
}

- (void)startReading
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(dataAvailableNotification:)
                                               name:NSFileHandleDataAvailableNotification
                                             object:_fileHandle];
  [_fileHandle waitForDataInBackgroundAndNotify];
}

- (void)stopReading
{
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:NSFileHandleDataAvailableNotification
                                                object:_fileHandle];
}

- (void)finishReadingToEndOfFile
{
  [self appendDataToBuffer:[_fileHandle readDataToEndOfFile]];
  [self processBuffer];
}

@end
