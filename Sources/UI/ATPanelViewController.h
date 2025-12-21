#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 配置面板：编辑步骤/延迟/循环次数，保存与切换方案，并控制开始/停止。
@interface ATPanelViewController : UIViewController

/// hostWindowProvider 用于取点模式（在该 window 上覆盖取点视图）。
- (instancetype)initWithHostWindowProvider:(UIWindow * _Nullable (^)(void))hostWindowProvider;

@end

NS_ASSUME_NONNULL_END

