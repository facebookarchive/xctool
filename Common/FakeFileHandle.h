
#import <Foundation/Foundation.h>

@interface FakeFileHandle : NSObject

@property (nonatomic, strong) NSMutableData *dataWritten;

- (NSString *)stringWritten;
- (int)fileDescriptor;
- (void)synchronizeFile;

@end
