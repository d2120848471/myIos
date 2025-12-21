#import "ATClickEngine.h"

#import "ATTapPlan.h"
#import "ATTapStep.h"
#import "ATHIDTapper.h"

NSNotificationName const ATClickEngineStateDidChangeNotification = @"ATClickEngineStateDidChangeNotification";

@interface ATClickEngine ()
@property (atomic, assign, readwrite, getter=isRunning) BOOL running;
@property (atomic, strong, readwrite, nullable) ATTapPlan *currentPlan;
@property (nonatomic, strong) ATHIDTapper *tapper;
@property (nonatomic, strong) dispatch_queue_t workerQueue;
@property (atomic, strong, nullable) NSUUID *runToken;
@end

@implementation ATClickEngine

- (instancetype)init
{
    self = [super init];
    if (self) {
        _tapper = [[ATHIDTapper alloc] init];
        _workerQueue = dispatch_queue_create("com.autotap.clickengine", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)startWithPlan:(ATTapPlan *)plan
{
    if (!plan) {
        return;
    }

    [self stop];

    NSUUID *token = [NSUUID UUID];
    self.runToken = token;
    self.currentPlan = plan;
    self.running = YES;
    [self notifyStateChanged];

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.workerQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        [strongSelf runPlan:plan token:token];

        // 仅当本次运行仍是当前 token 时，才落盘状态；避免“旧线程结束”覆盖新运行状态。
        if ([strongSelf isTokenCurrent:token]) {
            strongSelf.runToken = nil;
            strongSelf.running = NO;
            strongSelf.currentPlan = nil;
            [strongSelf notifyStateChanged];
        }
    });
}

- (void)stop
{
    self.runToken = nil;
    self.running = NO;
    self.currentPlan = nil;
    [self notifyStateChanged];
}

#pragma mark - 私有方法

- (void)runPlan:(ATTapPlan *)plan token:(NSUUID *)token
{
    if (plan.steps.count == 0) {
        return;
    }

    NSInteger loopCount = MAX(1, plan.loopCount);
    for (NSInteger loopIndex = 0; loopIndex < loopCount; loopIndex++) {
        if (![self isTokenCurrent:token]) {
            return;
        }

        for (ATTapStep *step in plan.steps) {
            if (![self isTokenCurrent:token]) {
                return;
            }

            [self.tapper tapAtPoint:step.point];

            NSInteger delayMs = MAX(0, step.delayMs);
            if (delayMs > 0) {
                [NSThread sleepForTimeInterval:((NSTimeInterval)delayMs) / 1000.0];
            }
        }
    }
}

- (BOOL)isTokenCurrent:(NSUUID *)token
{
    if (!token) {
        return NO;
    }
    NSUUID *current = self.runToken;
    if (!current) {
        return NO;
    }
    return [current isEqual:token];
}

- (void)notifyStateChanged
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:ATClickEngineStateDidChangeNotification object:self];
    });
}

@end
