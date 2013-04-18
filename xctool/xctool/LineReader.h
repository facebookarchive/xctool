
#import <Foundation/Foundation.h>

@interface LineReader : NSObject
{
  NSFileHandle *_fileHandle;
  NSMutableString *_buffer;
}

@property (nonatomic, copy) void (^didReadLineBlock)(NSString *);

- (id)initWithFileHandle:(NSFileHandle *)fileHandle;

- (void)startReading;
- (void)stopReading;
- (void)finishReadingToEndOfFile;

@end
