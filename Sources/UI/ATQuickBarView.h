#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 右侧快捷功能栏：添加点位/开始停止/展开面板。
@interface ATQuickBarView : UIView

@property (nonatomic, copy, nullable) void (^onAddStep)(void);
@property (nonatomic, copy, nullable) void (^onToggleRun)(void);
@property (nonatomic, copy, nullable) void (^onTogglePanel)(void);

/// 当前是否正在执行（影响按钮状态与文案）。
@property (nonatomic, assign, getter=isRunning) BOOL running;

/// 是否允许添加点位。
@property (nonatomic, assign) BOOL addEnabled;

@end

NS_ASSUME_NONNULL_END

