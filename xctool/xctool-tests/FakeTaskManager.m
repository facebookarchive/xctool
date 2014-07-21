
#import "FakeTaskManager.h"

#import "FakeTask.h"
#import "LaunchHandlers.h"
#import "Swizzle.h"
#import "XCToolUtil.h"

static FakeTaskManager *__sharedManager = nil;

static id NSTask_allocWithZone(id cls, SEL sel, NSZone *zone) __attribute((ns_returns_retained));
static id NSTask_allocWithZone(id cls, SEL sel, NSZone *zone)
{
  if ([[FakeTaskManager sharedManager] fakeTasksAreEnabled] &&
      cls != objc_getClass("FakeTask")) {
    return [FakeTask allocWithZone:zone];
  } else {
    return objc_msgSend(cls, @selector(__NSTask_allocWithZone:), zone);
  }
}

__attribute__((constructor)) static void initialize()
{
  XTSwizzleClassSelectorForFunction([NSTask class],
                                    @selector(allocWithZone:),
                                    (IMP)NSTask_allocWithZone);
}

@interface FakeTaskManager ()
@property (nonatomic, copy) NSMutableArray *launchedTasks;
@property (nonatomic, copy) NSMutableArray *launchedTasksToBeHidden;
@property (nonatomic, copy) NSMutableArray *launchHandlerBlocks;
@property (nonatomic, assign) BOOL fakeTasksAreEnabled;
@end

@implementation FakeTaskManager

+ (FakeTaskManager *)sharedManager
{
  if (__sharedManager == nil) {
    __sharedManager = [[FakeTaskManager alloc] init];
  }
  return __sharedManager;
}

- (id)init
{
  if (self = [super init])
  {
  }
  return self;
}

- (void)enableFakeTasks
{
  NSAssert(!_fakeTasksAreEnabled, @"Fake tasks are already enabled.");
  _fakeTasksAreEnabled = YES;
  _launchedTasks = [[NSMutableArray alloc] init];
  _launchedTasksToBeHidden = [[NSMutableArray alloc] init];
  _launchHandlerBlocks = [[NSMutableArray alloc] init];
}

- (void)disableFakeTasks
{
  NSAssert(_fakeTasksAreEnabled, @"Fake tasks weren't enabled.");
  _fakeTasksAreEnabled = NO;
  _launchedTasks = nil;
  _launchedTasksToBeHidden = nil;
  _launchHandlerBlocks = nil;
}

- (BOOL)fakeTasksAreEnabled
{
  return _fakeTasksAreEnabled;
}

- (void)hideTaskFromLaunchedTasks:(FakeTask *)task
{
  [_launchedTasksToBeHidden addObject:task];
}

- (NSArray *)launchedTasks
{
  NSMutableArray *result = [NSMutableArray array];

  for (FakeTask *task in [self allLaunchedTasks]) {
    if (![_launchedTasksToBeHidden containsObject:task]) {
      [result addObject:task];
    }
  }

  return result;
}

- (NSArray *)allLaunchedTasks
{
  NSAssert(_fakeTasksAreEnabled, @"Fake tasks are not enabled.");
  return _launchedTasks;
}

- (void)addLaunchHandlerBlocks:(NSArray *)handlerBlocks
{
  NSAssert(_fakeTasksAreEnabled,
           @"Only call 'addLaunchHandlerBlocks:' after 'enableFakeTasks'.");
  [_launchHandlerBlocks addObjectsFromArray:handlerBlocks];
}

- (void)runBlockWithFakeTasks:(void (^)(void))runBlock
{
  [self runBlockWithFakeTasks:runBlock withDefaultLaunchHandlers:YES];
}

- (NSArray *)defaultLaunchHandlers
{
  return @[
           // XcodeDeveloperDirPath()
           ^(FakeTask *task){
             if ([[task launchPath] isEqualToString:@"/usr/bin/xcode-select"] &&
                 [[task arguments] isEqualToArray:@[@"--print-path"]]) {
               [task pretendTaskReturnsStandardOutput:
                @"/Applications/Xcode.app/Contents/Developer"];
               [[FakeTaskManager sharedManager] hideTaskFromLaunchedTasks:task];
             }
           },
            // GetAvailableSDKsAndAliases()
            ^(FakeTask *task){
              if ([[task launchPath] hasSuffix:@"usr/bin/xcodebuild"] &&
                  [[task arguments] isEqualToArray:@[@"-sdk", @"-version"
                   ]]) {
                [task pretendTaskReturnsStandardOutput:
                 @"MacOSX10.7.sdk - OS X 10.7 (macosx10.7)\n\n"
                 @"MacOSX10.8.sdk - OS X 10.8 (macosx10.8)\n\n"
                 @"iPhoneOS6.1.sdk - iOS 6.1 (iphoneos6.1)\n\n"
                 @"iPhoneSimulator5.0.sdk - Simulator - iOS 5.0 (iphonesimulator5.0)\n\n"
                 @"iPhoneSimulator5.1.sdk - Simulator - iOS 5.1 (iphonesimulator5.1)\n\n"
                 @"iPhoneSimulator6.0.sdk - Simulator - iOS 6.0 (iphonesimulator6.0)\n\n"
                 @"iPhoneSimulator6.1.sdk - Simulator - iOS 6.1 (iphonesimulator6.1)\n\n"
                 @"Xcode 5.0.2\nBuild version 5A3005"];
                [[FakeTaskManager sharedManager] hideTaskFromLaunchedTasks:task];
              }
            },
           ];
}

- (void)runBlockWithFakeTasks:(void (^)(void))runBlock
    withDefaultLaunchHandlers:(BOOL)withDefaultLaunchHandlers
{
  [self enableFakeTasks];
  if (withDefaultLaunchHandlers) {
    [self addLaunchHandlerBlocks:[self defaultLaunchHandlers]];
  }

  @try {
    runBlock();
  }
  @catch (NSException *exception) {
    @throw exception;
  }
  @finally {
    [self disableFakeTasks];
  }
}

- (void)recordLaunchedTask:(FakeTask *)task
{
  NSAssert(_fakeTasksAreEnabled, @"Fake tasks are not enabled.");
  [_launchedTasks addObject:task];
}

- (void)callLaunchHandlersWithTask:(FakeTask *)task
{
  NSAssert(_fakeTasksAreEnabled, @"Fake tasks are not enabled.");
  for (void (^launchHandlerBlock)(FakeTask *) in _launchHandlerBlocks) {
    launchHandlerBlock(task);
  }
}

@end
