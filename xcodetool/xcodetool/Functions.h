
#import <Foundation/Foundation.h>

NSTask *TaskInstance(void);
void SetTaskInstanceBlock(NSTask *(^createTaskBlock)());
void ReturnFakeTasks(NSArray *tasks);
NSArray *ProjectsInWorkspace(NSString *workspacePath);
NSArray *SchemesInProject(NSString *xcodeprojPath);
NSArray *TestablesInScheme(NSString *schemePath, NSString *parentProjectPath);
NSArray *TestablesInWorkspaceAndScheme(NSString *workspacePath, NSString *scheme);
NSArray *TestablesInProjectAndScheme(NSString *projectPath, NSString *scheme);
NSArray *BuildablesForTestInWorkspaceAndScheme(NSString *workspacePath, NSString *scheme);
NSArray *BuildablesForTestInProjectAndScheme(NSString *projectPath, NSString *scheme);
NSDictionary *LaunchTaskAndCaptureOutput(NSTask *task);
void LaunchTaskAndFeedOuputLinesToBlock(NSTask *task, void (^block)(NSString *));
NSDictionary *BuildSettingsFromOutput(NSString *output);
NSString *AbsoluteExecutablePath(void);
NSString *PathToFBXcodeTestBinaries(void);
NSString *XcodeDeveloperDirPath(void);
NSString *StringForJSON(id object);
NSString *MakeTempFileWithPrefix(NSString *prefix);
NSArray *GetAvailableSDKs();