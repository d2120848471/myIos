#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 悬浮窗入口：负责创建透明透传 window、悬浮按钮与配置面板。
@interface ATWindowManager : NSObject

@property (nonatomic, strong, readonly, nullable) UIWindow *window;

+ (instancetype)shared;

/// 启动悬浮窗（可重复调用）。
- (void)start;

@end

NS_ASSUME_NONNULL_END

