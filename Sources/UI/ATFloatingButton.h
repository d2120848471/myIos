#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 可拖拽悬浮按钮。
@interface ATFloatingButton : UIButton

/// 运行中状态（用于 UI 提示）。
@property (nonatomic, assign, getter=isPlaying) BOOL playing;

@end

NS_ASSUME_NONNULL_END

