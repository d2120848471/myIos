#import "ATStepMarkerView.h"

@implementation ATStepMarkerView {
    UILabel *_numberLabel;
    UIPanGestureRecognizer *_pan;
    UITapGestureRecognizer *_tap;
}

- (instancetype)initWithStepIndex:(NSInteger)stepIndex
{
    self = [super initWithFrame:CGRectMake(0, 0, 44, 44)];
    if (self) {
        _stepIndex = stepIndex;

        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
        self.layer.cornerRadius = 22;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;

        _numberLabel = [[UILabel alloc] initWithFrame:self.bounds];
        _numberLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _numberLabel.textAlignment = NSTextAlignmentCenter;
        _numberLabel.textColor = [UIColor whiteColor];
        _numberLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        [self addSubview:_numberLabel];

        _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:_pan];

        _tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        _tap.cancelsTouchesInView = YES;
        [_tap requireGestureRecognizerToFail:_pan];
        [self addGestureRecognizer:_tap];

        [self refreshNumber];
    }
    return self;
}

- (void)setStepIndex:(NSInteger)stepIndex
{
    _stepIndex = stepIndex;
    [self refreshNumber];
}

- (void)refreshNumber
{
    NSInteger number = MAX(1, self.stepIndex + 1);
    _numberLabel.text = [NSString stringWithFormat:@"%ld", (long)number];
}

- (void)handleTap:(UITapGestureRecognizer *)tap
{
    if (tap.state != UIGestureRecognizerStateEnded) {
        return;
    }
    if (self.onTap) {
        self.onTap(self);
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan
{
    UIView *superview = self.superview;
    if (!superview) {
        return;
    }

    CGPoint translation = [pan translationInView:superview];
    CGPoint center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:superview];

    // 限制在屏幕范围内（留出半径）。
    CGFloat radius = CGRectGetWidth(self.bounds) / 2.0;
    CGFloat minX = radius + 6;
    CGFloat maxX = CGRectGetWidth(superview.bounds) - radius - 6;
    CGFloat minY = radius + 6 + superview.safeAreaInsets.top;
    CGFloat maxY = CGRectGetHeight(superview.bounds) - radius - 6 - superview.safeAreaInsets.bottom;

    center.x = MAX(minX, MIN(maxX, center.x));
    center.y = MAX(minY, MIN(maxY, center.y));
    self.center = center;

    if (self.onMove) {
        BOOL finished = (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled || pan.state == UIGestureRecognizerStateFailed);
        self.onMove(self, center, finished);
    }
}

@end

