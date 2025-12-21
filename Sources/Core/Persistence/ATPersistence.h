#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ATTapPlan;

/// 方案持久化：本地 JSON 文件保存/读取/删除/枚举。
@interface ATPersistence : NSObject

+ (instancetype)shared;

/// 返回所有已保存方案名称（按文件名排序）。
- (NSArray<NSString *> *)allPlanNames;

/// 读取指定方案。
- (nullable ATTapPlan *)loadPlanNamed:(NSString *)name error:(NSError **)error;

/// 保存方案（同名覆盖）。
- (BOOL)savePlan:(ATTapPlan *)plan error:(NSError **)error;

/// 删除方案。
- (BOOL)deletePlanNamed:(NSString *)name error:(NSError **)error;

/// 加载“上次使用的方案”；不存在则返回默认方案（不会自动落盘）。
- (ATTapPlan *)loadLastOrDefaultPlan;

/// 设置/获取上次使用方案名称（仅记录，不校验文件存在性）。
- (void)setLastPlanName:(NSString *)name;
- (nullable NSString *)lastPlanName;

@end

NS_ASSUME_NONNULL_END

