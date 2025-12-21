#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// 使用 IOHIDEvent 注入模拟触控（需要对应权限/环境支持）。
@interface ATHIDTapper : NSObject

/// 当前环境是否可用（例如 IOHID 客户端创建成功）。
- (BOOL)isAvailable;

/// 点击一次：按下+抬起。
- (void)tapAtPoint:(CGPoint)point;

@end

NS_ASSUME_NONNULL_END
