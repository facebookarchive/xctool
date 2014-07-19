
#import <Foundation/Foundation.h>

@interface FakeFileHandle : NSObject

@property (nonatomic, retain, readonly) NSMutableData *dataWritten;
- (NSString *)stringWritten;
- (int)fileDescriptor;
- (void)synchronizeFile;

@end
