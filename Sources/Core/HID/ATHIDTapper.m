#import "ATHIDTapper.h"

#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <mach/mach_time.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);

extern IOHIDEventRef IOHIDEventCreateDigitizerEvent(CFAllocatorRef allocator,
                                                    uint64_t timeStamp,
                                                    uint32_t transducerType,
                                                    uint32_t transducerIndex,
                                                    uint32_t identity,
                                                    uint32_t eventMask,
                                                    uint32_t buttonMask,
                                                    double x,
                                                    double y,
                                                    double z,
                                                    double tipPressure,
                                                    double twist,
                                                    bool range,
                                                    bool touch,
                                                    uint32_t options);

extern IOHIDEventRef IOHIDEventCreateDigitizerFingerEvent(CFAllocatorRef allocator,
                                                          uint64_t timeStamp,
                                                          uint32_t index,
                                                          uint32_t identity,
                                                          uint32_t eventMask,
                                                          uint32_t buttonMask,
                                                          double x,
                                                          double y,
                                                          double z,
                                                          double tipPressure,
                                                          double twist,
                                                          bool range,
                                                          bool touch,
                                                          uint32_t options);

extern void IOHIDEventAppendEvent(IOHIDEventRef parent, IOHIDEventRef child, uint32_t options);
extern void IOHIDEventSetSenderID(IOHIDEventRef event, uint64_t senderID);

@interface ATHIDTapper ()
@property (nonatomic, assign) IOHIDEventSystemClientRef client;
@property (nonatomic, assign) uint64_t senderID;
@end

@implementation ATHIDTapper

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setupClientIfNeeded];
    }
    return self;
}

- (void)dealloc
{
    if (_client) {
        CFRelease(_client);
        _client = nil;
    }
}

- (BOOL)isAvailable
{
    [self setupClientIfNeeded];
    return self.client != nil;
}

- (void)tapAtPoint:(CGPoint)point
{
    [self setupClientIfNeeded];
    if (!self.client) {
        return;
    }

    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    if (screenSize.width <= 0 || screenSize.height <= 0) {
        return;
    }

    // 归一化坐标（0~1），与常见 IOHID digitizer 注入方式保持一致。
    double x = MAX(0.0, MIN(1.0, point.x / screenSize.width));
    double y = MAX(0.0, MIN(1.0, point.y / screenSize.height));

    // 触控序列：按下(范围内+触摸) → 抬起(范围内+不触摸) → 离开(不在范围内)。
    // 这样比仅“down/up”更贴近系统真实事件，且能减少部分 App 丢失结束事件的概率。
    [self sendTouchWithX:x y:y range:YES touch:YES];

    // 轻微停顿模拟真实点击；避免过短导致部分 App 丢事件。
    [NSThread sleepForTimeInterval:0.02];

    [self sendTouchWithX:x y:y range:YES touch:NO];

    // 再补一个离开范围事件，避免部分组件将“range=true,touch=false”视为悬停状态。
    [NSThread sleepForTimeInterval:0.01];
    [self sendTouchWithX:x y:y range:NO touch:NO];
}

#pragma mark - 私有方法

- (void)setupClientIfNeeded
{
    if (_client) {
        return;
    }
    _client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);

    // senderID 取一个非 0 的随机值即可。
    _senderID = (((uint64_t)arc4random()) << 32) | (uint64_t)arc4random();
    if (_senderID == 0) {
        _senderID = 1;
    }
}

- (void)sendTouchWithX:(double)x y:(double)y range:(BOOL)range touch:(BOOL)touch
{
    uint64_t timeStamp = mach_absolute_time();

    // 说明：
    // - 这里复用常见的 digitizer + finger 子事件模式，兼容性更好。
    // - transducerType 使用 0x23，参考已分析的同类 dylib 调用习惯。
    // - eventMask 同时携带 range + touch；由 range/touch 组合表达按下、抬起、离开范围等状态变化。
    uint32_t eventMask = 0x3;
    double pressure = touch ? 1.0 : 0.0;
    IOHIDEventRef parent = IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault,
                                                          timeStamp,
                                                          0x23,
                                                          0,
                                                          0,
                                                          eventMask,
                                                          0,
                                                          x,
                                                          y,
                                                          0,
                                                          pressure,
                                                          0,
                                                          range ? true : false,
                                                          touch ? true : false,
                                                          0);

    if (!parent) {
        return;
    }

    IOHIDEventRef finger = IOHIDEventCreateDigitizerFingerEvent(kCFAllocatorDefault,
                                                                timeStamp,
                                                                1,
                                                                1,
                                                                eventMask,
                                                                0,
                                                                x,
                                                                y,
                                                                0,
                                                                pressure,
                                                                0,
                                                                range ? true : false,
                                                                touch ? true : false,
                                                                0);
    if (finger) {
        IOHIDEventSetSenderID(finger, self.senderID);
        IOHIDEventAppendEvent(parent, finger, 0);
        CFRelease(finger);
    }

    IOHIDEventSetSenderID(parent, self.senderID);
    IOHIDEventSystemClientDispatchEvent(self.client, parent);
    CFRelease(parent);
}

@end
