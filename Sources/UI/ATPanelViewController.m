#import "ATPanelViewController.h"

#import "ATClickEngine.h"
#import "ATPersistence.h"
#import "ATTapPlan.h"
#import "ATTapStep.h"
#import "ATTouchPicker.h"
#import "ATQuickBarView.h"
#import "ATStepMarkerView.h"

@interface ATPanelViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) UIWindow * _Nullable (^hostWindowProvider)(void);
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) ATClickEngine *engine;
@property (nonatomic, strong) ATPersistence *persistence;
@property (nonatomic, strong) ATTouchPicker *picker;
@property (nonatomic, strong) ATTapPlan *plan;
@property (nonatomic, strong, nullable) ATQuickBarView *quickBar;
@property (nonatomic, strong) NSMutableArray<ATStepMarkerView *> *markerViews;
@property (nonatomic, assign) BOOL hudInstalled;
@end

@implementation ATPanelViewController

- (instancetype)initWithHostWindowProvider:(UIWindow * _Nullable (^)(void))hostWindowProvider
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _hostWindowProvider = [hostWindowProvider copy];
        _engine = [[ATClickEngine alloc] init];
        _persistence = [ATPersistence shared];
        _picker = [[ATTouchPicker alloc] init];
        _plan = [_persistence loadLastOrDefaultPlan];
        _markerViews = [NSMutableArray array];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleEngineStateChanged:)
                                                     name:ATClickEngineStateDidChangeNotification
                                                   object:_engine];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    self.view.layer.cornerRadius = 14;
    self.view.layer.masksToBounds = YES;

    UITableViewStyle style = UITableViewStyleInsetGrouped;
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:style];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16);
    [self.view addSubview:_tableView];

    // 右侧快捷栏 + 拖拽点位（避免全屏遮罩影响目标 App 交互）。
    [self installHUDIfNeeded];
    [self reloadMarkers];
    [self syncHUDState];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.tableView.frame = self.view.bounds;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return 2; // 名称/循环
        case 1:
            return self.plan.steps.count + 1; // 步骤 + 添加
        case 2:
            return 4; // 开始停止/保存/加载/删除
        default:
            return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return @"方案设置";
        case 1:
            return @"步骤列表";
        case 2:
            return @"操作";
        default:
            return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
        cell.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:1 alpha:0.75];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }

    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    cell.textLabel.textColor = [UIColor whiteColor];

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"名称";
            cell.detailTextLabel.text = self.plan.name ?: @"";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.textLabel.text = @"循环次数";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)MAX(1, self.plan.loopCount)];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        return cell;
    }

    if (indexPath.section == 1) {
        if (indexPath.row == self.plan.steps.count) {
            cell.textLabel.text = @"➕ 添加步骤（拖拽）";
            cell.detailTextLabel.text = @"";
            cell.accessoryType = UITableViewCellAccessoryNone;
            return cell;
        }

        ATTapStep *step = self.plan.steps[indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"步骤 %ld", (long)indexPath.row + 1];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"x=%.0f y=%.0f 延迟=%ldms",
                                     step.point.x,
                                     step.point.y,
                                     (long)MAX(0, step.delayMs)];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }

    // section == 2
    switch (indexPath.row) {
        case 0: {
            BOOL running = self.engine.isRunning;
            cell.textLabel.text = running ? @"⏹ 停止执行" : @"▶︎ 开始执行";
            cell.detailTextLabel.text = running ? @"运行中" : @"";
            cell.textLabel.textColor = running ? [UIColor colorWithRed:1 green:0.35 blue:0.25 alpha:1] : [UIColor colorWithRed:0.35 green:1 blue:0.55 alpha:1];
            break;
        }
        case 1:
            cell.textLabel.text = @"💾 保存方案";
            cell.detailTextLabel.text = @"";
            break;
        case 2:
            cell.textLabel.text = @"📂 加载方案";
            cell.detailTextLabel.text = @"";
            break;
        case 3:
            cell.textLabel.text = @"🗑 删除当前方案";
            cell.detailTextLabel.text = @"";
            cell.textLabel.textColor = [UIColor colorWithRed:1 green:0.35 blue:0.25 alpha:1];
            break;
        default:
            break;
    }
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            [self promptEditPlanName];
        } else {
            [self promptEditLoopCount];
        }
        return;
    }

    if (indexPath.section == 1) {
        if (indexPath.row == self.plan.steps.count) {
            [self addStepByQuickBar];
            return;
        }

        [self showStepActionsAtIndex:indexPath.row sourceView:[tableView cellForRowAtIndexPath:indexPath]];
        return;
    }

    if (indexPath.section == 2) {
        switch (indexPath.row) {
            case 0:
                [self toggleStartStop];
                break;
            case 1:
                [self saveCurrentPlan];
                break;
            case 2:
                [self showLoadPlanSheetFromSourceView:[tableView cellForRowAtIndexPath:indexPath]];
                break;
            case 3:
                [self confirmDeleteCurrentPlanFromSourceView:[tableView cellForRowAtIndexPath:indexPath]];
                break;
            default:
                break;
        }
        return;
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section != 1 || indexPath.row >= self.plan.steps.count) {
        return nil;
    }

    __weak typeof(self) weakSelf = self;
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                              title:@"删除"
                                                                            handler:^(__kindof UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            completionHandler(NO);
            return;
        }
        [strongSelf removeStepAtIndex:indexPath.row];
        completionHandler(YES);
    }];

    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
    return config;
}

#pragma mark - 交互

- (void)toggleStartStop
{
    if (self.engine.isRunning) {
        [self.engine stop];
    } else {
        BOOL ok = [self.engine startWithPlan:self.plan];
        if (!ok) {
            [self showMessage:@"启动失败：请先添加步骤，并确认当前 TrollStore 环境支持 IOHID 触控注入。"
                        title:@"无法开始执行"];
        } else {
            // 开始执行后自动收起面板，避免遮挡目标 App，且防止注入点击落到面板自身导致“看起来没点到”。
            self.view.hidden = YES;
        }
    }
    [self.tableView reloadData];
    [self syncHUDState];
}

- (void)saveCurrentPlan
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"保存方案"
                                                                   message:@"输入方案名称（同名会覆盖）"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"例如：Boss连点";
        textField.text = self.plan.name ?: @"";
    }];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSString *name = alert.textFields.firstObject.text ?: @"";
        strongSelf.plan.name = name;
        NSError *saveError = nil;
        BOOL ok = [strongSelf.persistence savePlan:strongSelf.plan error:&saveError];
        if (!ok) {
            [strongSelf showError:saveError title:@"保存失败"];
        } else {
            [strongSelf.tableView reloadData];
        }
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showLoadPlanSheetFromSourceView:(UIView *)sourceView
{
    NSArray<NSString *> *names = [self.persistence allPlanNames];
    if (names.count == 0) {
        [self showMessage:@"当前没有已保存的方案" title:@"加载方案"];
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"加载方案"
                                                                   message:@"选择要加载的方案"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    __weak typeof(self) weakSelf = self;
    for (NSString *name in names) {
        [sheet addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf loadPlanNamed:name];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentActionSheet:sheet fromSourceView:sourceView];
}

- (void)confirmDeleteCurrentPlanFromSourceView:(UIView *)sourceView
{
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"删除方案"
                                                                   message:@"确认删除当前方案文件？（不会影响内存中当前编辑内容）"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSError *error = nil;
        BOOL ok = [strongSelf.persistence deletePlanNamed:strongSelf.plan.name error:&error];
        if (!ok) {
            [strongSelf showError:error title:@"删除失败"];
        } else {
            [strongSelf showMessage:@"已删除" title:@"删除方案"];
        }
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentActionSheet:sheet fromSourceView:sourceView];
}

- (void)promptEditPlanName
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"修改名称"
                                                                   message:@"用于保存/切换方案"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = self.plan.name ?: @"";
    }];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSString *name = alert.textFields.firstObject.text ?: @"";
        strongSelf.plan.name = name;
        [strongSelf.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)promptEditLoopCount
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"循环次数"
                                                                   message:@"填写 >= 1 的整数"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%ld", (long)MAX(1, self.plan.loopCount)];
    }];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSString *text = alert.textFields.firstObject.text ?: @"";
        NSInteger value = text.integerValue;
        strongSelf.plan.loopCount = MAX(1, value);
        [strongSelf.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)addStepByPickingPoint
{
    UIWindow *window = self.hostWindowProvider ? self.hostWindowProvider() : nil;
    if (!window) {
        [self showMessage:@"未找到可用 window，无法取点" title:@"取点失败"];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self.picker beginPickInWindow:window completion:^(CGPoint point) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf promptDelayForNewStepAtPoint:point];
    } cancel:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf showMessage:@"已取消取点（长按可取消）" title:@"取点"];
    }];
}

- (void)promptDelayForNewStepAtPoint:(CGPoint)point
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置延迟"
                                                                   message:@"本步骤点击后，等待多少毫秒进入下一步"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.placeholder = @"例如：500";
        textField.text = @"500";
    }];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"添加" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSInteger delayMs = alert.textFields.firstObject.text.integerValue;
        ATTapStep *step = [[ATTapStep alloc] initWithPoint:point delayMs:delayMs];

        NSMutableArray<ATTapStep *> *steps = [strongSelf.plan.steps mutableCopy] ?: [NSMutableArray array];
        [steps addObject:step];
        strongSelf.plan.steps = steps;
        [strongSelf.tableView reloadData];
        [strongSelf reloadMarkers];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showStepActionsAtIndex:(NSInteger)index sourceView:(UIView *)sourceView
{
    if (index < 0 || index >= self.plan.steps.count) {
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"步骤操作"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;

    [sheet addAction:[UIAlertAction actionWithTitle:@"修改延迟" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf promptEditDelayAtIndex:index];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"拖动调整位置" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf repickPointAtIndex:index];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"删除步骤" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf removeStepAtIndex:index];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentActionSheet:sheet fromSourceView:sourceView];
}

- (void)promptEditDelayAtIndex:(NSInteger)index
{
    ATTapStep *step = self.plan.steps[index];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"修改延迟"
                                                                   message:@"填写毫秒（>= 0）"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%ld", (long)MAX(0, step.delayMs)];
    }];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        NSInteger delayMs = alert.textFields.firstObject.text.integerValue;

        NSMutableArray<ATTapStep *> *steps = [strongSelf.plan.steps mutableCopy];
        ATTapStep *updated = [[ATTapStep alloc] initWithPoint:step.point delayMs:delayMs];
        steps[index] = updated;
        strongSelf.plan.steps = steps;
        [strongSelf.tableView reloadData];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)repickPointAtIndex:(NSInteger)index
{
    [self installHUDIfNeeded];
    if (index < 0 || index >= self.markerViews.count) {
        [self showMessage:@"未找到对应的点位标记，请先添加步骤" title:@"调整位置"];
        return;
    }

    ATStepMarkerView *marker = self.markerViews[index];
    marker.hidden = NO;
    marker.userInteractionEnabled = YES;

    // 自动收起面板，避免遮挡点位与目标 App。
    if (!self.view.hidden) {
        [self togglePanelVisibility];
    }

    // 给用户一个明显的视觉提示：请直接拖动编号点位调整坐标。
    [UIView animateWithDuration:0.12 animations:^{
        marker.transform = CGAffineTransformMakeScale(1.18, 1.18);
        marker.alpha = 1.0;
    } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.12 animations:^{
            marker.transform = CGAffineTransformIdentity;
        }];
    }];

    [self showToast:[NSString stringWithFormat:@"拖动「%ld」号点位到目标位置", (long)index + 1]];
}

- (void)removeStepAtIndex:(NSInteger)index
{
    if (index < 0 || index >= self.plan.steps.count) {
        return;
    }
    NSMutableArray<ATTapStep *> *steps = [self.plan.steps mutableCopy];
    [steps removeObjectAtIndex:index];
    self.plan.steps = steps;
    [self.tableView reloadData];
    [self reloadMarkers];
}

- (void)loadPlanNamed:(NSString *)name
{
    // 加载新方案前先停止，避免执行中修改数据造成混乱。
    [self.engine stop];

    NSError *error = nil;
    ATTapPlan *plan = [self.persistence loadPlanNamed:name error:&error];
    if (!plan) {
        [self showError:error title:@"加载失败"];
        return;
    }

    self.plan = plan;
    [self.persistence setLastPlanName:plan.name];
    [self.tableView reloadData];
    [self reloadMarkers];
}

#pragma mark - 引擎状态

- (void)handleEngineStateChanged:(NSNotification *)note
{
    [self.tableView reloadData];
    [self syncHUDState];
}

#pragma mark - 弹窗辅助

- (void)presentActionSheet:(UIAlertController *)sheet fromSourceView:(UIView *)sourceView
{
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover && sourceView) {
        popover.sourceView = sourceView;
        popover.sourceRect = sourceView.bounds;
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showError:(NSError *)error title:(NSString *)title
{
    NSString *message = error.localizedDescription ?: @"未知错误";
    [self showMessage:message title:title];
}

- (void)showMessage:(NSString *)message title:(NSString *)title
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - HUD：右侧快捷栏 + 拖拽点位

- (UIView *)hostRootView
{
    UIWindow *window = self.hostWindowProvider ? self.hostWindowProvider() : nil;
    UIView *rootView = window.rootViewController.view;
    if (![rootView isKindOfClass:[UIView class]]) {
        return nil;
    }
    return rootView;
}

- (void)installHUDIfNeeded
{
    if (self.hudInstalled) {
        return;
    }

    UIView *rootView = [self hostRootView];
    if (!rootView) {
        return;
    }
    self.hudInstalled = YES;

    __weak typeof(self) weakSelf = self;
    ATQuickBarView *bar = [[ATQuickBarView alloc] initWithFrame:CGRectZero];
    bar.onAddStep = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf addStepByQuickBar];
    };
    bar.onToggleRun = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf toggleStartStop];
    };
    bar.onTogglePanel = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf togglePanelVisibility];
    };

    CGFloat margin = 10;
    CGSize barSize = bar.bounds.size;
    bar.frame = CGRectMake(CGRectGetWidth(rootView.bounds) - barSize.width - margin,
                           (CGRectGetHeight(rootView.bounds) - barSize.height) / 2.0,
                           barSize.width,
                           barSize.height);
    bar.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [rootView addSubview:bar];
    self.quickBar = bar;
}

- (CGPoint)clampCenter:(CGPoint)center inSuperview:(UIView *)superview radius:(CGFloat)radius
{
    CGFloat minX = radius + 6;
    CGFloat maxX = CGRectGetWidth(superview.bounds) - radius - 6;
    CGFloat minY = radius + 6 + superview.safeAreaInsets.top;
    CGFloat maxY = CGRectGetHeight(superview.bounds) - radius - 6 - superview.safeAreaInsets.bottom;

    center.x = MAX(minX, MIN(maxX, center.x));
    center.y = MAX(minY, MIN(maxY, center.y));
    return center;
}

- (void)reloadMarkers
{
    [self installHUDIfNeeded];
    UIView *rootView = [self hostRootView];
    if (!rootView) {
        return;
    }

    for (ATStepMarkerView *marker in self.markerViews) {
        [marker removeFromSuperview];
    }
    [self.markerViews removeAllObjects];

    __weak typeof(self) weakSelf = self;
    [self.plan.steps enumerateObjectsUsingBlock:^(ATTapStep *step, NSUInteger idx, __unused BOOL *stop) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        ATStepMarkerView *marker = [[ATStepMarkerView alloc] initWithStepIndex:(NSInteger)idx];
        CGFloat radius = CGRectGetWidth(marker.bounds) / 2.0;
        CGPoint clamped = [strongSelf clampCenter:step.point inSuperview:rootView radius:radius];
        marker.center = clamped;
        if (!CGPointEqualToPoint(clamped, step.point)) {
            step.point = clamped;
        }

        marker.onMove = ^(ATStepMarkerView *m, CGPoint newCenter, BOOL finished) {
            __strong typeof(weakSelf) innerSelf = weakSelf;
            if (!innerSelf) {
                return;
            }
            NSInteger stepIndex = m.stepIndex;
            if (stepIndex < 0 || stepIndex >= innerSelf.plan.steps.count) {
                return;
            }
            ATTapStep *targetStep = innerSelf.plan.steps[stepIndex];
            targetStep.point = newCenter;

            if (finished) {
                [innerSelf.tableView reloadData];
            }
        };

        marker.onTap = ^(ATStepMarkerView *m) {
            __strong typeof(weakSelf) innerSelf = weakSelf;
            if (!innerSelf) {
                return;
            }
            if (innerSelf.engine.isRunning) {
                return;
            }
            NSInteger stepIndex = m.stepIndex;
            if (stepIndex < 0 || stepIndex >= innerSelf.plan.steps.count) {
                return;
            }
            [innerSelf showStepActionsAtIndex:stepIndex sourceView:m];
        };

        [rootView addSubview:marker];
        [strongSelf.markerViews addObject:marker];
    }];

    if (self.quickBar.superview == rootView) {
        [rootView bringSubviewToFront:self.quickBar];
    }
    [self syncHUDState];
}

- (void)showToast:(NSString *)text
{
    UIView *rootView = [self hostRootView];
    if (!rootView || text.length == 0) {
        return;
    }

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = text;
    label.numberOfLines = 2;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor whiteColor];
    label.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    label.layer.cornerRadius = 10;
    label.layer.masksToBounds = YES;
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];

    CGFloat margin = 14;
    CGFloat maxWidth = MIN(CGRectGetWidth(rootView.bounds) - margin * 2, 360);
    CGSize size = [label sizeThatFits:CGSizeMake(maxWidth - 16, CGFLOAT_MAX)];
    label.frame = CGRectMake((CGRectGetWidth(rootView.bounds) - maxWidth) / 2.0,
                             margin + rootView.safeAreaInsets.top,
                             maxWidth,
                             size.height + 16);
    label.alpha = 0;
    [rootView addSubview:label];

    [UIView animateWithDuration:0.16 animations:^{
        label.alpha = 1;
    } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.2 delay:1.2 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            label.alpha = 0;
        } completion:^(__unused BOOL finished2) {
            [label removeFromSuperview];
        }];
    }];
}

- (void)syncHUDState
{
    BOOL running = self.engine.isRunning;
    self.quickBar.running = running;
    self.quickBar.addEnabled = !running;

    for (ATStepMarkerView *marker in self.markerViews) {
        marker.hidden = running;
        marker.userInteractionEnabled = !running;
    }
}

- (void)addStepByQuickBar
{
    if (self.engine.isRunning) {
        return;
    }

    UIView *rootView = [self hostRootView];
    if (!rootView) {
        [self showMessage:@"未找到可用 window，无法添加点位" title:@"添加失败"];
        return;
    }

    CGPoint defaultPoint = CGPointMake(CGRectGetMidX(rootView.bounds), CGRectGetMidY(rootView.bounds));
    // 避免默认点位被右侧栏遮住，向左偏移一点。
    defaultPoint.x -= 70;

    ATTapStep *step = [[ATTapStep alloc] initWithPoint:defaultPoint delayMs:500];
    NSMutableArray<ATTapStep *> *steps = [self.plan.steps mutableCopy] ?: [NSMutableArray array];
    [steps addObject:step];
    self.plan.steps = steps;

    [self.tableView reloadData];
    [self reloadMarkers];
    [self repickPointAtIndex:(NSInteger)self.plan.steps.count - 1];
}

- (void)togglePanelVisibility
{
    if (self.engine.isRunning) {
        return;
    }

    UIView *panelView = self.view;
    BOOL willShow = panelView.hidden;
    if (willShow) {
        panelView.hidden = NO;
        panelView.alpha = 0;
        panelView.transform = CGAffineTransformMakeScale(0.98, 0.98);
        [UIView animateWithDuration:0.18 animations:^{
            panelView.alpha = 1;
            panelView.transform = CGAffineTransformIdentity;
        }];
    } else {
        [UIView animateWithDuration:0.18 animations:^{
            panelView.alpha = 0;
            panelView.transform = CGAffineTransformMakeScale(0.98, 0.98);
        } completion:^(__unused BOOL finished) {
            panelView.hidden = YES;
            panelView.alpha = 1;
            panelView.transform = CGAffineTransformIdentity;
        }];
    }
}

@end
