#import "ATQuickBarView.h"

@implementation ATQuickBarView {
    UIButton *_addButton;
    UIButton *_runButton;
    UIButton *_panelButton;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    // 让背景区域“点穿透”，避免影响目标 App 点击；仅按钮本身接收事件。
    if (view == self) {
        return nil;
    }
    return view;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.frame = CGRectMake(0, 0, 54, 170);
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
        self.layer.cornerRadius = 14;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;

        _addButton = [self buttonWithTitle:@"＋"];
        [_addButton addTarget:self action:@selector(handleAddTapped) forControlEvents:UIControlEventTouchUpInside];

        _runButton = [self buttonWithTitle:@"▶︎"];
        [_runButton addTarget:self action:@selector(handleRunTapped) forControlEvents:UIControlEventTouchUpInside];

        _panelButton = [self buttonWithTitle:@"≡"];
        [_panelButton addTarget:self action:@selector(handlePanelTapped) forControlEvents:UIControlEventTouchUpInside];

        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_addButton, _runButton, _panelButton]];
        stack.axis = UILayoutConstraintAxisVertical;
        stack.distribution = UIStackViewDistributionEqualSpacing;
        stack.alignment = UIStackViewAlignmentCenter;
        stack.spacing = 10;
        stack.frame = self.bounds;
        stack.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:stack];

        self.addEnabled = YES;
        self.running = NO;
    }
    return self;
}

- (UIButton *)buttonWithTitle:(NSString *)title
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(0, 0, 44, 44);
    button.layer.cornerRadius = 12;
    button.layer.masksToBounds = YES;
    button.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    button.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    return button;
}

- (void)setRunning:(BOOL)running
{
    _running = running;
    if (running) {
        _runButton.backgroundColor = [UIColor colorWithRed:0.95 green:0.35 blue:0.25 alpha:0.92];
        [_runButton setTitle:@"⏹" forState:UIControlStateNormal];
    } else {
        _runButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
        [_runButton setTitle:@"▶︎" forState:UIControlStateNormal];
    }
}

- (void)setAddEnabled:(BOOL)addEnabled
{
    _addEnabled = addEnabled;
    _addButton.enabled = addEnabled;
    _addButton.alpha = addEnabled ? 1.0 : 0.35;
}

- (void)handleAddTapped
{
    if (!self.addEnabled) {
        return;
    }
    if (self.onAddStep) {
        self.onAddStep();
    }
}

- (void)handleRunTapped
{
    if (self.onToggleRun) {
        self.onToggleRun();
    }
}

- (void)handlePanelTapped
{
    if (self.onTogglePanel) {
        self.onTogglePanel();
    }
}

@end
