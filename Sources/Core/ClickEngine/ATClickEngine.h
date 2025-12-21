#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ATTapPlan;

/// 引擎状态变化通知（object 为 ATClickEngine 实例）。
FOUNDATION_EXPORT NSNotificationName const ATClickEngineStateDidChangeNotification;

/// 点击执行引擎：按步骤调度点击，支持循环次数与随时停止。
@interface ATClickEngine : NSObject

@property (atomic, assign, readonly, getter=isRunning) BOOL running;

/// 当前正在执行的方案（未运行时为 nil）。
@property (atomic, strong, readonly, nullable) ATTapPlan *currentPlan;

/// 开始执行（若正在运行会先停止再启动）。
/// 返回是否启动成功（例如：步骤为空、或当前环境不支持 IOHID 注入时会失败）。
- (BOOL)startWithPlan:(ATTapPlan *)plan;

/// 停止执行（可重复调用）。
- (void)stop;

@end

NS_ASSUME_NONNULL_END
