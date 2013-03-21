
#import <Foundation/Foundation.h>

NSTask *TaskInstance(void);
void SetTaskInstanceBlock(NSTask *(^createTaskBlock)());
void ReturnFakeTasks(NSArray *tasks);
NSDictionary *LaunchTaskAndCaptureOutput(NSTask *task);
void LaunchTaskAndFeedOuputLinesToBlock(NSTask *task, void (^block)(NSString *));
NSDictionary *BuildSettingsFromOutput(NSString *output);
NSString *AbsoluteExecutablePath(void);
NSString *PathToFBXcodetoolBinaries(void);
NSString *XcodeDeveloperDirPath(void);
NSString *StringForJSON(id object);
NSString *MakeTempFileWithPrefix(NSString *prefix);
NSArray *GetAvailableSDKs();
