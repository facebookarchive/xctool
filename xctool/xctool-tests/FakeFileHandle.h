
#import <Foundation/Foundation.h>

@interface FakeFileHandle : NSObject
{
  NSMutableData *_dataWritten;
}

- (NSData *)dataWritten;
- (NSString *)stringWritten;
- (int)fileDescriptor;
- (void)synchronizeFile;

@end
