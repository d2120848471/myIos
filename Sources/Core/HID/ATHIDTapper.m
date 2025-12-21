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
        _client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
        // senderID 取一个非 0 的随机值即可。
        _senderID = (((uint64_t)arc4random()) << 32) | (uint64_t)arc4random();
        if (_senderID == 0) {
            _senderID = 1;
        }
    }
    return self;
}

- (void)tapAtPoint:(CGPoint)point
{
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

    [self sendTouchWithX:x y:y down:YES];

    // 轻微停顿模拟真实点击；避免过短导致部分 App 丢事件。
    [NSThread sleepForTimeInterval:0.02];

    [self sendTouchWithX:x y:y down:NO];
}

#pragma mark - 私有方法

- (void)sendTouchWithX:(double)x y:(double)y down:(BOOL)down
{
    uint64_t timeStamp = mach_absolute_time();

    // 说明：
    // - 这里复用常见的 digitizer + finger 子事件模式，兼容性更好。
    // - transducerType 使用 0x23，参考已分析的同类 dylib 调用习惯。
    IOHIDEventRef parent = IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault,
                                                          timeStamp,
                                                          0x23,
                                                          0,
                                                          0,
                                                          0x2,
                                                          0,
                                                          0,
                                                          0,
                                                          0,
                                                          0,
                                                          0,
                                                          true,
                                                          down,
                                                          0);

    if (!parent) {
        return;
    }

    IOHIDEventRef finger = IOHIDEventCreateDigitizerFingerEvent(kCFAllocatorDefault,
                                                                timeStamp,
                                                                1,
                                                                3,
                                                                0x2,
                                                                0,
                                                                x,
                                                                y,
                                                                0,
                                                                down ? 1.0 : 0.0,
                                                                0,
                                                                true,
                                                                down,
                                                                0);
    if (finger) {
        IOHIDEventAppendEvent(parent, finger, 0);
        CFRelease(finger);
    }

    IOHIDEventSetSenderID(parent, self.senderID);
    IOHIDEventSystemClientDispatchEvent(self.client, parent);
    CFRelease(parent);
}

@end

