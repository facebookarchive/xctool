
#import <Foundation/Foundation.h>

@interface Reporter : NSObject
{
  NSFileHandle *_outputHandle;
}

+ (Reporter *)reporterWithName:(NSString *)name outputPath:(NSString *)outputPath;

// The reporter will stream output to here.  Usually this will be "-" to route
// to standard out, but it might point to a file if the -reporter param
// specified an output path.
@property (nonatomic, retain) NSString *outputPath;
@property (nonatomic, readonly) NSFileHandle *outputHandle;

- (id)initWithOutputPath:(NSString *)outputPath;

- (void)setupOutputHandleWithStandardOutput:(NSFileHandle *)standardOutput;
- (void)handleEvent:(NSString *)event;

- (void)beginBuildTarget:(NSDictionary *)event;
- (void)endBuildTarget:(NSDictionary *)event;
- (void)beginBuildCommand:(NSDictionary *)event;
- (void)endBuildCommand:(NSDictionary *)event;
- (void)beginXcodebuild:(NSDictionary *)event;
- (void)endXcodebuild:(NSDictionary *)event;
- (void)beginOctest:(NSDictionary *)event;
- (void)endOctest:(NSDictionary *)event;
- (void)beginTestSuite:(NSDictionary *)event;
- (void)endTestSuite:(NSDictionary *)event;
- (void)beginTest:(NSDictionary *)event;
- (void)endTest:(NSDictionary *)event;
- (void)testOutput:(NSDictionary *)event;

@end
