
#import <Foundation/Foundation.h>

@class Action;
@class Options;

@interface Reporter : NSObject
{
  NSFileHandle *_outputHandle;
}

+ (Reporter *)reporterWithName:(NSString *)name outputPath:(NSString *)outputPath options:(Options *)options;

// The reporter will stream output to here.  Usually this will be "-" to route
// to standard out, but it might point to a file if the -reporter param
// specified an output path.
@property (nonatomic, retain) NSString *outputPath;
@property (nonatomic, readonly) NSFileHandle *outputHandle;
@property (nonatomic, retain) Options *options;

- (void)setupOutputHandleWithStandardOutput:(NSFileHandle *)standardOutput;
- (void)handleEvent:(NSDictionary *)event;

- (void)beginAction:(Action *)action;
- (void)endAction:(Action *)action succeeded:(BOOL)succeeded;
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

/*
 To be called just before xcodetool exits.
 */
- (void)close;

@end
