#import "ATFloatingButton.h"

@implementation ATFloatingButton {
    UIPanGestureRecognizer *_pan;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.frame = CGRectMake(0, 0, 56, 56);
        self.layer.cornerRadius = 28;
        self.layer.masksToBounds = YES;
        self.backgroundColor = [UIColor colorWithRed:0.18 green:0.45 blue:0.95 alpha:0.92];
        self.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        [self setTitle:@"AT" forState:UIControlStateNormal];
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.layer.borderWidth = 1;
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;

        _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:_pan];
    }
    return self;
}

- (void)setPlaying:(BOOL)playing
{
    _playing = playing;
    if (playing) {
        self.backgroundColor = [UIColor colorWithRed:0.95 green:0.35 blue:0.25 alpha:0.92];
        [self setTitle:@"⏹" forState:UIControlStateNormal];
    } else {
        self.backgroundColor = [UIColor colorWithRed:0.18 green:0.45 blue:0.95 alpha:0.92];
        [self setTitle:@"AT" forState:UIControlStateNormal];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan
{
    UIView *view = self;
    UIView *superview = view.superview;
    if (!superview) {
        return;
    }

    CGPoint translation = [pan translationInView:superview];
    CGPoint center = CGPointMake(view.center.x + translation.x, view.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:superview];

    // 限制在屏幕范围内（留出半径）。
    CGFloat radius = CGRectGetWidth(view.bounds) / 2.0;
    CGFloat minX = radius + 6;
    CGFloat maxX = CGRectGetWidth(superview.bounds) - radius - 6;
    CGFloat minY = radius + 6 + superview.safeAreaInsets.top;
    CGFloat maxY = CGRectGetHeight(superview.bounds) - radius - 6 - superview.safeAreaInsets.bottom;

    center.x = MAX(minX, MIN(maxX, center.x));
    center.y = MAX(minY, MIN(maxY, center.y));
    view.center = center;
}

@end
