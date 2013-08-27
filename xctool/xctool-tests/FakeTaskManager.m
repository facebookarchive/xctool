
#import "FakeTaskManager.h"

#import "FakeTask.h"
#import "Swizzle.h"
#import "XCToolUtil.h"

static FakeTaskManager *__sharedManager = nil;

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
  [_launchedTasks release];
  _launchedTasks = nil;
  [_launchedTasksToBeHidden release];
  _launchedTasksToBeHidden = nil;
  [_launchHandlerBlocks release];
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
              if ([[task launchPath] isEqualToString:@"/bin/bash"] &&
                  [[task arguments] isEqualToArray:@[
                   @"-c",
                   @"/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"
                   @" -showsdks | perl -ne '/-sdk (.*?)([\\d\\.]+)$/ && print \"$1 $2\n\"'; "
                   @"exit ${PIPESTATUS[0]};",
                   ]]) {
                [task pretendTaskReturnsStandardOutput:
                 @"macosx 10.7\n"
                 @"macosx 10.8\n"
                 @"iphoneos 6.1\n"
                 @"iphonesimulator 5.0\n"
                 @"iphonesimulator 5.1\n"
                 @"iphonesimulator 6.0\n"
                 @"iphonesimulator 6.1\n"];
                [[FakeTaskManager sharedManager] hideTaskFromLaunchedTasks:task];
              }
            },
           ];
}

- (void)runBlockWithFakeTasks:(void (^)(void))runBlock
    withDefaultLaunchHandlers:(BOOL)withDefaultLaunchHandlers
{
  [self enableFakeTasks];
  [self addLaunchHandlerBlocks:[self defaultLaunchHandlers]];

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
