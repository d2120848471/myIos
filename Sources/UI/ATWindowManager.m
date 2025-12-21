#import "ATWindowManager.h"

#import "ATClickEngine.h"
#import "ATFloatingButton.h"
#import "ATPanelViewController.h"

@interface ATOverlayWindow : UIWindow
@end

@implementation ATOverlayWindow

/// 透传：点到空白区域时返回 nil，让事件落到下层 App。
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    if (!view) {
        return nil;
    }
    if (view == self || view == self.rootViewController.view) {
        return nil;
    }
    return view;
}

@end

@interface ATWindowManager ()
@property (nonatomic, strong, readwrite, nullable) ATOverlayWindow *window;
@property (nonatomic, strong) UIViewController *rootViewController;
@property (nonatomic, strong) ATFloatingButton *floatingButton;
@property (nonatomic, strong) ATPanelViewController *panelViewController;
@property (nonatomic, weak, nullable) ATClickEngine *engine;
@property (nonatomic, assign) BOOL started;
@end

@implementation ATWindowManager

+ (instancetype)shared
{
    static ATWindowManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ATWindowManager alloc] init];
    });
    return instance;
}

- (void)start
{
    if (self.started) {
        return;
    }
    self.started = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self setupWindowIfNeeded];
    });
}

#pragma mark - UI

- (void)setupWindowIfNeeded
{
    if (self.window) {
        return;
    }

    ATOverlayWindow *window = nil;

    if (@available(iOS 13.0, *)) {
        UIWindowScene *targetScene = nil;
        NSSet<UIScene *> *scenes = [UIApplication sharedApplication].connectedScenes;
        for (UIScene *scene in scenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                targetScene = (UIWindowScene *)scene;
                break;
            }
        }
        if (targetScene) {
            window = [[ATOverlayWindow alloc] initWithWindowScene:targetScene];
        }
    }

    if (!window) {
        window = [[ATOverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }

    window.backgroundColor = [UIColor clearColor];
    window.windowLevel = UIWindowLevelAlert + 1000;

    UIViewController *root = [[UIViewController alloc] init];
    root.view.backgroundColor = [UIColor clearColor];
    window.rootViewController = root;

    self.window = window;
    self.rootViewController = root;

    [self setupFloatingButton];
    [self setupPanel];
    [self setupObserversIfNeeded];

    window.hidden = NO;
}

- (void)setupFloatingButton
{
    ATFloatingButton *button = [[ATFloatingButton alloc] initWithFrame:CGRectZero];
    button.center = CGPointMake(60, 200);
    [button addTarget:self action:@selector(handleFloatingButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.rootViewController.view addSubview:button];
    self.floatingButton = button;
}

- (void)setupPanel
{
    __weak typeof(self) weakSelf = self;
    ATPanelViewController *panel = [[ATPanelViewController alloc] initWithHostWindowProvider:^UIWindow * _Nullable{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        return strongSelf.window;
    }];

    CGFloat margin = 12;
    CGSize screenSize = self.rootViewController.view.bounds.size;
    if (screenSize.width <= 0 || screenSize.height <= 0) {
        screenSize = [UIScreen mainScreen].bounds.size;
    }

    // 面板默认做得更“紧凑”，避免遮挡目标 App 的主要交互区域；内容可滚动，不影响功能完整性。
    CGFloat maxWidth = MIN(340, screenSize.width - margin * 2);
    CGFloat maxHeight = MIN(480, floor(screenSize.height * 0.5));
    CGFloat width = MAX(280, maxWidth);
    CGFloat height = MAX(320, MIN(maxHeight, screenSize.height - margin * 2));
    panel.view.frame = CGRectMake((screenSize.width - width) / 2.0, (screenSize.height - height) / 2.0, width, height);
    panel.view.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    panel.view.hidden = YES;

    [self.rootViewController addChildViewController:panel];
    [self.rootViewController.view addSubview:panel.view];
    [panel didMoveToParentViewController:self.rootViewController];

    self.panelViewController = panel;
}

- (void)handleFloatingButtonTapped
{
    // 运行中优先“一键停止”，避免误触打开面板后注入点击落到面板自身。
    if (self.engine.isRunning) {
        [self.engine stop];
        [self hidePanel];
        return;
    }

    BOOL willShow = self.panelViewController.view.hidden;
    if (willShow) {
        [self showPanel];
    } else {
        [self hidePanel];
    }
}

- (void)showPanel
{
    UIView *panelView = self.panelViewController.view;
    if (!panelView.hidden) {
        return;
    }
    panelView.hidden = NO;
    panelView.alpha = 0;
    panelView.transform = CGAffineTransformMakeScale(0.98, 0.98);

    [UIView animateWithDuration:0.18 animations:^{
        panelView.alpha = 1;
        panelView.transform = CGAffineTransformIdentity;
    }];
}

- (void)hidePanel
{
    UIView *panelView = self.panelViewController.view;
    if (panelView.hidden) {
        return;
    }
    [UIView animateWithDuration:0.18 animations:^{
        panelView.alpha = 0;
        panelView.transform = CGAffineTransformMakeScale(0.98, 0.98);
    } completion:^(BOOL finished) {
        panelView.hidden = YES;
        panelView.alpha = 1;
        panelView.transform = CGAffineTransformIdentity;
    }];
}

#pragma mark - 通知

- (void)setupObserversIfNeeded
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleEngineStateChanged:)
                                                     name:ATClickEngineStateDidChangeNotification
                                                   object:nil];
    });
}

- (void)handleEngineStateChanged:(NSNotification *)note
{
    if (![note.object isKindOfClass:[ATClickEngine class]]) {
        return;
    }

    ATClickEngine *engine = (ATClickEngine *)note.object;
    self.engine = engine;
    self.floatingButton.playing = engine.isRunning;

    if (engine.isRunning) {
        [self hidePanel];
    }
}

@end
