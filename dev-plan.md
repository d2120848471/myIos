# AutoTap 开发计划

## 项目概述
iOS TrollStore 环境下的 dylib 自动点击插件，支持悬浮窗 UI、多点击位置管理、方案导入导出。

## 技术栈
- 语言: Objective-C
- 目标: iOS 16.6 + TrollStore
- 构建: Theos + GitHub Actions
- 点击方案: IOHIDEvent 注入（模拟触控坐标）

## 任务分解

### T1: 悬浮窗 UI 框架
- **描述**: 透明透传 UIWindow + 可拖拽悬浮按钮 + 面板骨架
- **文件范围**:
  - `Sources/Entry/Tweak.m` - dylib 入口
  - `Sources/UI/ATWindowManager.m` - 窗口管理
  - `Sources/UI/ATFloatingButton.m` - 悬浮按钮
  - `Sources/UI/ATPanelViewController.m` - 面板控制器
- **依赖**: 无
- **测试**: `make package`

### T2: 数据模型与持久化
- **描述**: TapPlan/TapStep 数据结构 + JSON 编解码 + 存储
- **文件范围**:
  - `Sources/Core/Models/ATTapStep.m` - 点击步骤模型
  - `Sources/Core/Models/ATTapPlan.m` - 方案模型
  - `Sources/Core/Persistence/ATPersistence.m` - 持久化管理
- **依赖**: 无 (可与 T1 并行)
- **测试**: `make package`

### T3: 取点与点击执行
- **描述**: 取点模式 + ClickEngine 调度 + IOHIDEvent 触发
- **文件范围**:
  - `Sources/Core/TouchPicker/ATTouchPicker.m` - 坐标选取
  - `Sources/Core/ClickEngine/ATClickEngine.m` - 点击调度
  - `Sources/Core/HID/ATHIDTapper.m` - IOHIDEvent 注入
- **依赖**: T1, T2
- **测试**: `make package`

### T4: GitHub Actions CI
- **描述**: macOS runner 构建 dylib + 产物发布
- **文件范围**:
  - `.github/workflows/build.yml` - CI 配置
  - `Makefile` - Theos 构建配置
  - `control` - 包信息
- **依赖**: 无 (可与 T1-T3 并行)
- **测试**: GitHub Actions 自动运行

## 依赖关系图
```
T1 (UI) ──────┐
              ├──→ T3 (取点+执行)
T2 (数据) ────┘

T4 (CI) ──────→ 独立并行
```

## 交付物
- `com.autotap.dylib` - 注入用动态库
- 示例 JSON 配置文件
- README 使用说明

## 验收标准
- 悬浮窗正常显示，不遮挡交互
- 可添加/删除点击位置
- 可设置每个点击的延迟
- 方案可保存/加载/导入/导出
- GitHub Actions 自动构建成功

