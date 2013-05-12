
#import <Foundation/Foundation.h>

@class FakeTask;

@interface FakeTaskManager : NSObject
{
  NSMutableArray *_launchedTasks;
  NSMutableArray *_launchedTasksToBeHidden;
  NSMutableArray *_launchHandlerBlocks;
  BOOL _fakeTasksAreEnabled;
}

+ (FakeTaskManager *)sharedManager;

- (BOOL)fakeTasksAreEnabled;

/**
 * Makes all -[NSTask alloc] calls allocate FakeTask objects.
 */
- (void)enableFakeTasks;

/**
 * Stops making all -[NSTask alloc] calls allocate FakeTask objects.
 */
- (void)disableFakeTasks;

/**
 * Array of blocks in the form of (void (^)(FakeTask *)).  These blocks are
 * called for each fake task at the top of the -[FakeTask launch] method.  The
 * block can then use the -[FakeTask pretend*] methods to make the task return
 * fake output.
 */
- (void)addLaunchHandlerBlocks:(NSArray *)handlerBlocks;

/**
 * Called by FakeTask to record launched tasks.
 */
- (void)recordLaunchedTask:(FakeTask *)task;

/**
 * Called by FakeTask to call all the launch handler blocks.
 */
- (void)callLaunchHandlersWithTask:(FakeTask *)task;

/**
 * Will make sure that the given task is excluded from the 'launchedTasks'
 * list.  (It is still available via 'allLaunchedTasks').
 */
- (void)hideTaskFromLaunchedTasks:(FakeTask *)task;

/**
 * Returns fake tasks launched in between calls to 'enableFakeTasks' and
 * 'disableFakeTasks'.
 */
- (NSArray *)launchedTasks;

/**
 * Like 'launchedTasks', but returns all tasks even those that have been hidden.
 */
- (NSArray *)allLaunchedTasks;

/**
 * Runs a block, calling 'enableFakeTasks' before and calling 'disableFakeTasks'
 * after it finishes.
 */
- (void)runBlockWithFakeTasks:(void (^)(void))runBlock;

/**
 * Runs a block, calling 'enableFakeTasks' before and calling 'disableFakeTasks'
 * after it finishes.
 *
 * If 'withDefaultLaunchHandlers' is YES, some standard launch handlers will get
 * used that fake out some of the less interesting NSTask invocations we do.
 */
- (void)runBlockWithFakeTasks:(void (^)(void))runBlock
    withDefaultLaunchHandlers:(BOOL)withDefaultLaunchHandlers;

@end
