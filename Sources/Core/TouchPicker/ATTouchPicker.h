#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class UIWindow;

/// 取点器：进入取点模式后，用户在屏幕上点一下即可返回坐标。
@interface ATTouchPicker : NSObject

typedef void (^ATTouchPickerCompletion)(CGPoint point);
typedef void (^ATTouchPickerCancel)(void);

/// 开始取点（会在 window 上覆盖一层透明视图用于捕获触控）。
- (void)beginPickInWindow:(UIWindow *)window completion:(ATTouchPickerCompletion)completion cancel:(nullable ATTouchPickerCancel)cancel;

/// 主动取消取点。
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
