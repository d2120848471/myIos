#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// 单个点击步骤：在指定坐标点击一次，然后等待 `delayMs` 再进入下一步。
@interface ATTapStep : NSObject

@property (nonatomic, assign) CGPoint point;
@property (nonatomic, assign) NSInteger delayMs;

- (instancetype)initWithPoint:(CGPoint)point delayMs:(NSInteger)delayMs;

/// 序列化为可直接写入 JSON 的对象（NSDictionary）。
- (NSDictionary *)jsonObject;

/// 从 JSON 对象反序列化。
+ (nullable instancetype)stepWithJSONObject:(id)object error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

