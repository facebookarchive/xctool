
#import <Foundation/Foundation.h>

/**
 * Returns an NSTask instance, or when under test, returns a fake NSTask instance
 * returned by whatever block is set via SetTaskInstanceBlock.  This is pretty crude
 * but functional.  A nicer way might be to swizzle alloc to return fake NSTask instances
 * in tests.
 */
NSTask *TaskInstance(void);

/**
 * Tests can register a block that gets called for each TaskInstance().  In here, they
 * can return a fake NSTask.
 */
void SetTaskInstanceBlock(NSTask *(^createTaskBlock)());

/**
 * Tests can pass in a list of fake NSTasks that will get returned sequentially from
 * calls to TaskInstance().
 */
void ReturnFakeTasks(NSArray *tasks);

/**
 * Launchs a task, waits for exit, and returns a dictionary like
 * { @"stdout": "...", @"stderr": "..." }
 */
NSDictionary *LaunchTaskAndCaptureOutput(NSTask *task);

/**
 * Launchs a task, waits for exit, and feeds lines from standard out to a block.
 */
void LaunchTaskAndFeedOuputLinesToBlock(NSTask *task, void (^block)(NSString *));
