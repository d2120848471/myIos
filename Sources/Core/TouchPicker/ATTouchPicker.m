#import "ATTouchPicker.h"

#import <UIKit/UIKit.h>

@interface ATTouchPickerOverlayView : UIView
@property (nonatomic, copy) ATTouchPickerCompletion completion;
@property (nonatomic, copy, nullable) ATTouchPickerCancel cancel;
@end

@implementation ATTouchPickerOverlayView {
    UILabel *_tipLabel;
    UIView *_dotView;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.15];
        self.userInteractionEnabled = YES;

        _tipLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _tipLabel.text = @"取点模式：点击屏幕选择位置（点空白处也可以）";
        _tipLabel.numberOfLines = 0;
        _tipLabel.textAlignment = NSTextAlignmentCenter;
        _tipLabel.textColor = [UIColor whiteColor];
        _tipLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
        _tipLabel.layer.cornerRadius = 10;
        _tipLabel.layer.masksToBounds = YES;
        _tipLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        [self addSubview:_tipLabel];

        _dotView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 14)];
        _dotView.backgroundColor = [UIColor colorWithRed:1 green:0.2 blue:0.2 alpha:0.95];
        _dotView.layer.cornerRadius = 7;
        _dotView.layer.masksToBounds = YES;
        _dotView.hidden = YES;
        [self addSubview:_dotView];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [self addGestureRecognizer:tap];

        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPress.minimumPressDuration = 0.6;
        [self addGestureRecognizer:longPress];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat margin = 18;
    CGFloat width = MIN(self.bounds.size.width - margin * 2, 360);
    CGSize size = [_tipLabel sizeThatFits:CGSizeMake(width - 16, CGFLOAT_MAX)];
    _tipLabel.frame = CGRectMake((self.bounds.size.width - width) / 2.0,
                                 margin + self.safeAreaInsets.top,
                                 width,
                                 size.height + 16);
}

- (void)handleTap:(UITapGestureRecognizer *)tap
{
    CGPoint point = [tap locationInView:self];
    _dotView.center = point;
    _dotView.hidden = NO;

    if (self.completion) {
        self.completion(point);
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)press
{
    if (press.state != UIGestureRecognizerStateBegan) {
        return;
    }

    // 长按取消（避免误触时无法退出）。
    if (self.cancel) {
        self.cancel();
    }
}

@end

@interface ATTouchPicker ()
@property (nonatomic, weak) UIWindow *hostWindow;
@property (nonatomic, strong) ATTouchPickerOverlayView *overlayView;
@end

@implementation ATTouchPicker

- (void)beginPickInWindow:(UIWindow *)window completion:(ATTouchPickerCompletion)completion cancel:(ATTouchPickerCancel)cancel
{
    if (!window || !completion) {
        return;
    }

    [self cancel];

    self.hostWindow = window;

    ATTouchPickerOverlayView *overlay = [[ATTouchPickerOverlayView alloc] initWithFrame:window.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    __weak typeof(self) weakSelf = self;
    overlay.completion = ^(CGPoint point) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf cancel];
        completion(point);
    };
    overlay.cancel = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf cancel];
        if (cancel) {
            cancel();
        }
    };

    self.overlayView = overlay;
    [window addSubview:overlay];
}

- (void)cancel
{
    [self.overlayView removeFromSuperview];
    self.overlayView = nil;
    self.hostWindow = nil;
}

@end

