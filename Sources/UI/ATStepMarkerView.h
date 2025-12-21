#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ATStepMarkerView;

typedef void (^ATStepMarkerMoveHandler)(ATStepMarkerView *marker, CGPoint newCenter, BOOL finished);
typedef void (^ATStepMarkerTapHandler)(ATStepMarkerView *marker);

/// 屏幕上的编号点位：可拖拽调整坐标，点击可触发更多操作。
@interface ATStepMarkerView : UIView

/// 0-based 步骤索引。
@property (nonatomic, assign) NSInteger stepIndex;

/// 拖拽移动回调（newCenter 为 marker 在父视图坐标系下的 center）。
@property (nonatomic, copy, nullable) ATStepMarkerMoveHandler onMove;

/// 点击回调。
@property (nonatomic, copy, nullable) ATStepMarkerTapHandler onTap;

- (instancetype)initWithStepIndex:(NSInteger)stepIndex;

/// 更新显示的编号（显示为 stepIndex + 1）。
- (void)refreshNumber;

@end

NS_ASSUME_NONNULL_END

