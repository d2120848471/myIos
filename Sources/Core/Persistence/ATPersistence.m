#import "ATPersistence.h"

#import "ATTapPlan.h"

static NSString *const ATPersistenceErrorDomain = @"com.autotap.ATPersistence";
static NSString *const ATUserDefaultsLastPlanNameKey = @"ATLastPlanName";

typedef NS_ENUM(NSInteger, ATPersistenceErrorCode) {
    ATPersistenceErrorCodeInvalidName = 1,
    ATPersistenceErrorCodeIO = 2,
    ATPersistenceErrorCodeInvalidJSON = 3,
};

@implementation ATPersistence

+ (instancetype)shared
{
    static ATPersistence *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ATPersistence alloc] init];
    });
    return instance;
}

- (NSArray<NSString *> *)allPlanNames
{
    NSString *plansDir = [self plansDirectoryPath];
    NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:plansDir error:nil] ?: @[];

    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSString *file in files) {
        if (![file.pathExtension.lowercaseString isEqualToString:@"json"]) {
            continue;
        }
        NSString *name = file.stringByDeletingPathExtension;
        if (name.length > 0) {
            [names addObject:name];
        }
    }

    [names sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return names;
}

- (ATTapPlan *)loadPlanNamed:(NSString *)name error:(NSError **)error
{
    NSString *safeName = [self safePlanName:name];
    if (safeName.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:ATPersistenceErrorDomain
                                         code:ATPersistenceErrorCodeInvalidName
                                     userInfo:@{NSLocalizedDescriptionKey : @"方案名称非法"}];
        }
        return nil;
    }

    NSString *path = [self planPathForName:safeName];
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!data) {
        return nil;
    }

    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (!obj) {
        return nil;
    }

    ATTapPlan *plan = [ATTapPlan planWithJSONObject:obj error:error];
    if (!plan) {
        return nil;
    }

    // 以文件名为准，避免导入的 JSON name 与文件不一致导致 UI 混乱。
    plan.name = safeName;
    return plan;
}

- (BOOL)savePlan:(ATTapPlan *)plan error:(NSError **)error
{
    NSString *safeName = [self safePlanName:plan.name];
    if (safeName.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:ATPersistenceErrorDomain
                                         code:ATPersistenceErrorCodeInvalidName
                                     userInfo:@{NSLocalizedDescriptionKey : @"方案名称非法"}];
        }
        return NO;
    }

    NSDictionary *json = [plan jsonObject];
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:error];
    if (!data) {
        return NO;
    }

    NSString *plansDir = [self plansDirectoryPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:plansDir]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:plansDir
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:error]) {
            return NO;
        }
    }

    NSString *path = [self planPathForName:safeName];
    if (![data writeToFile:path options:NSDataWritingAtomic error:error]) {
        return NO;
    }

    [self setLastPlanName:safeName];
    return YES;
}

- (BOOL)deletePlanNamed:(NSString *)name error:(NSError **)error
{
    NSString *safeName = [self safePlanName:name];
    if (safeName.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:ATPersistenceErrorDomain
                                         code:ATPersistenceErrorCodeInvalidName
                                     userInfo:@{NSLocalizedDescriptionKey : @"方案名称非法"}];
        }
        return NO;
    }

    NSString *path = [self planPathForName:safeName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return YES;
    }

    return [[NSFileManager defaultManager] removeItemAtPath:path error:error];
}

- (ATTapPlan *)loadLastOrDefaultPlan
{
    NSString *lastName = [self lastPlanName];
    if (lastName.length > 0) {
        ATTapPlan *plan = [self loadPlanNamed:lastName error:nil];
        if (plan) {
            return plan;
        }
    }

    // 默认方案：空步骤 + 1 次循环（由 UI 引导用户添加）。
    return [[ATTapPlan alloc] initWithName:@"默认方案" loopCount:1 steps:@[]];
}

- (void)setLastPlanName:(NSString *)name
{
    NSString *safeName = [self safePlanName:name];
    if (safeName.length == 0) {
        return;
    }
    [[NSUserDefaults standardUserDefaults] setObject:safeName forKey:ATUserDefaultsLastPlanNameKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)lastPlanName
{
    id obj = [[NSUserDefaults standardUserDefaults] objectForKey:ATUserDefaultsLastPlanNameKey];
    if ([obj isKindOfClass:[NSString class]] && ((NSString *)obj).length > 0) {
        return (NSString *)obj;
    }
    return nil;
}

#pragma mark - 私有方法

- (NSString *)plansDirectoryPath
{
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *base = paths.firstObject;
    if (base.length == 0) {
        // 极端情况下退化到 Library 目录。
        NSArray<NSString *> *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        base = libraryPaths.firstObject ?: NSTemporaryDirectory();
    }
    return [base stringByAppendingPathComponent:@"AutoTap/Plans"];
}

- (NSString *)planPathForName:(NSString *)safeName
{
    return [[self plansDirectoryPath] stringByAppendingPathComponent:[safeName stringByAppendingPathExtension:@"json"]];
}

/// 文件名安全化：去掉路径分隔符与不可见字符，避免目录穿越。
- (NSString *)safePlanName:(NSString *)name
{
    if (![name isKindOfClass:[NSString class]]) {
        return @"";
    }

    NSString *trimmed = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return @"";
    }

    NSCharacterSet *invalid = [NSCharacterSet characterSetWithCharactersInString:@"/\\:*?\"<>|"];
    NSArray<NSString *> *parts = [trimmed componentsSeparatedByCharactersInSet:invalid];
    NSString *joined = [parts componentsJoinedByString:@"_"];

    // 控制文件名长度，避免极端输入导致文件系统异常。
    if (joined.length > 64) {
        joined = [joined substringToIndex:64];
    }
    return joined;
}

@end

