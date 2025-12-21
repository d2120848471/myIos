#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ATTapStep;

/// 点击方案：步骤序列 + 循环次数。
@interface ATTapPlan : NSObject

/// 方案名称（用于文件名与 UI 展示）。
@property (nonatomic, copy) NSString *name;

/// 循环次数（>= 1）。若为 1 表示只执行一轮。
@property (nonatomic, assign) NSInteger loopCount;

@property (nonatomic, copy) NSArray<ATTapStep *> *steps;

- (instancetype)initWithName:(NSString *)name loopCount:(NSInteger)loopCount steps:(NSArray<ATTapStep *> *)steps;

/// 序列化为可直接写入 JSON 的对象（NSDictionary）。
- (NSDictionary *)jsonObject;

/// 从 JSON 对象反序列化。
+ (nullable instancetype)planWithJSONObject:(id)object error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

