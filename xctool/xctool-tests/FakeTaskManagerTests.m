
#import <SenTestingKit/SenTestingKit.h>

#import <objc/message.h>
#import <objc/runtime.h>

#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"

@interface FakeTaskManagerTests : SenTestCase
@end

@implementation FakeTaskManagerTests

- (void)testCanRunRealTasks
{
  NSTask *task = [[[NSTask alloc] init] autorelease];
  [task setLaunchPath:@"/bin/echo"];
  [task setArguments:@[@"hello"]];

  NSDictionary *output = LaunchTaskAndCaptureOutput(task);
  assertThat(output[@"stdout"], equalTo(@"hello\n"));
}

- (void)testCanMakeAllTasksFake
{
  [[FakeTaskManager sharedManager] enableFakeTasks];
  NSTask *task = [[[NSTask alloc] init] autorelease];
  assertThat([[task class] description], equalTo(@"FakeTask"));
  [[FakeTaskManager sharedManager] disableFakeTasks];
}

- (void)testCanGetPretendStandardOutput
{
  [[FakeTaskManager sharedManager] enableFakeTasks];
  NSTask *task = [[[NSTask alloc] init] autorelease];
  [task setLaunchPath:@"/bin/something"];
  [(FakeTask *)task pretendTaskReturnsStandardOutput:@"some stdout string"];
  assertThat(LaunchTaskAndCaptureOutput(task)[@"stdout"],
             equalTo(@"some stdout string"));
  [[FakeTaskManager sharedManager] disableFakeTasks];
}

- (void)testCanGetPretendStandardError
{
  [[FakeTaskManager sharedManager] enableFakeTasks];
  NSTask *task = [[[NSTask alloc] init] autorelease];
  [task setLaunchPath:@"/bin/something"];
  [(FakeTask *)task pretendTaskReturnsStandardError:@"some stderr string"];
  assertThat(LaunchTaskAndCaptureOutput(task)[@"stderr"],
             equalTo(@"some stderr string"));
  [[FakeTaskManager sharedManager] disableFakeTasks];
}

- (void)testCanGetPretendExitStatus
{
  [[FakeTaskManager sharedManager] enableFakeTasks];
  NSTask *task = [[[NSTask alloc] init] autorelease];
  [task setLaunchPath:@"/bin/something"];
  [(FakeTask *)task pretendExitStatusOf:5];
  [task launch];
  [task waitUntilExit];
  assertThatInt([task terminationStatus], equalToInt(5));
  [[FakeTaskManager sharedManager] disableFakeTasks];
}

- (void)testLaunchedTasksAreRecorded
{
  [[FakeTaskManager sharedManager] enableFakeTasks];
  NSTask *task1 = [[[NSTask alloc] init] autorelease];
  [task1 setLaunchPath:@"/bin/echo"];
  [task1 setArguments:@[@"task1"]];
  [task1 launch];
  [task1 waitUntilExit];

  NSTask *task2 = [[[NSTask alloc] init] autorelease];
  [task2 setLaunchPath:@"/bin/echo"];
  [task2 setArguments:@[@"task2"]];
  [task2 launch];
  [task2 waitUntilExit];

  NSArray *launchedTasks = [[FakeTaskManager sharedManager] launchedTasks];
  assertThatInteger([launchedTasks count], equalToInteger(2));
  assertThat([launchedTasks[0] arguments], equalTo(@[@"task1"]));
  assertThat([launchedTasks[1] arguments], equalTo(@[@"task2"]));

  [[FakeTaskManager sharedManager] disableFakeTasks];
}

- (void)testRunBlockWithFakeTasksWorks
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    NSTask *task1 = [[[NSTask alloc] init] autorelease];
    [task1 setLaunchPath:@"/bin/echo"];
    [task1 setArguments:@[@"task1"]];
    [task1 launch];
    [task1 waitUntilExit];

    assertThatInteger([[[FakeTaskManager sharedManager] launchedTasks] count],
                      equalToInteger(1));
  }];
}

- (void)testRunBlockWithFakeTasksPropogatesExceptionsAndDisablesFakeTasks
{
  @try {
    [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
      assertThatBool([[FakeTaskManager sharedManager] fakeTasksAreEnabled],
                     equalToBool(YES));

      [NSException raise:NSGenericException format:@"An exception."];
    }];
  }
  @catch (NSException *exception) {
    assertThat([exception reason], equalTo(@"An exception."));
  }
  @finally {
  }

  // runBlockWithFakeTasks: should still make sure fake tasks get disabled when
  // the block finishes, even if there is an exception.
  assertThatBool([[FakeTaskManager sharedManager] fakeTasksAreEnabled],
                 equalToBool(NO));
}

- (void)testCanSetLaunchHandlerBlocksToTickleFakeTasks
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    // These blocks will get called at the top of -[FakeTask launch].
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     ^(FakeTask *task){
      [task pretendTaskReturnsStandardOutput:@"some stdout!"];
    },
     ]];

    NSTask *task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath:@"/bin/echo"];
    [task setArguments:@[@"task1"]];
    [task launch];
    [task waitUntilExit];

    assertThat(LaunchTaskAndCaptureOutput(task)[@"stdout"],
               equalTo(@"some stdout!"));
  }];
}

/**
 * Our list of default launch handlers should sufficiently fake out the
 * boring NSTask invocations in our code.  These are things we don't care to
 * see when writing most of our tests.
 */
- (void)testDefaultLaunchHandlers
{
  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    // This function calls out to xcode-select
    NSString *path = XcodeDeveloperDirPath();
    assertThat(path, equalTo(@"/Applications/Xcode.app/Contents/Developer"));

    // This function calls out to xcodebuild -showsdks
    NSDictionary *sdksAndAliases = GetAvailableSDKsAndAliases();
    assertThat(sdksAndAliases,
               equalTo(@{
                       @"iphoneos" : @"iphoneos6.1",
                       @"iphoneos6.1" : @"iphoneos6.1",
                       @"iphonesimulator" : @"iphonesimulator6.1",
                       @"iphonesimulator5.0" : @"iphonesimulator5.0",
                       @"iphonesimulator5.1" : @"iphonesimulator5.1",
                       @"iphonesimulator6.0" : @"iphonesimulator6.0",
                       @"iphonesimulator6.1" : @"iphonesimulator6.1",
                       @"macosx" : @"macosx10.8",
                       @"macosx10.7" : @"macosx10.7",
                       @"macosx10.8" : @"macosx10.8",
                       }));

    // Both of the above should be in the allLaunchedTasks list.  Since XcodeDeveloperDirPath()
    // is called by GetAvailableSDKsAndAliases(), it will show up twice.
    assertThatInteger([[[FakeTaskManager sharedManager] allLaunchedTasks] count],
                      equalToInteger(3));

    // But, not in the 'launchedTasks' list.  The launch handler should have
    // hidden them.
    assertThatInteger([[[FakeTaskManager sharedManager] launchedTasks] count],
                      equalToInteger(0));

  }
                               withDefaultLaunchHandlers:YES];
}

@end
