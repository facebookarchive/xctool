
#import <Foundation/Foundation.h>

@interface FakeFileHandle : NSObject
{
  NSMutableData *_dataWritten;
}

- (NSData *)dataWritten;
- (int)fileDescriptor;
- (void)synchronizeFile;

@end
