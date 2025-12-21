#import "ATTapPlan.h"

#import "ATTapStep.h"

static NSString *const ATTapPlanErrorDomain = @"com.autotap.ATTapPlan";

typedef NS_ENUM(NSInteger, ATTapPlanErrorCode) {
    ATTapPlanErrorCodeInvalidJSON = 1,
};

static NSInteger const ATTapPlanCurrentVersion = 1;

@implementation ATTapPlan

- (instancetype)initWithName:(NSString *)name loopCount:(NSInteger)loopCount steps:(NSArray<ATTapStep *> *)steps
{
    self = [super init];
    if (self) {
        _name = (name.length > 0) ? [name copy] : @"未命名方案";
        _loopCount = MAX(1, loopCount);
        _steps = [steps copy] ?: @[];
    }
    return self;
}

- (NSDictionary *)jsonObject
{
    NSMutableArray *steps = [NSMutableArray arrayWithCapacity:self.steps.count];
    for (ATTapStep *step in self.steps) {
        [steps addObject:[step jsonObject]];
    }

    return @{
        @"version": @(ATTapPlanCurrentVersion),
        @"name": self.name ?: @"未命名方案",
        @"loopCount": @(MAX(1, self.loopCount)),
        @"steps": steps,
    };
}

+ (instancetype)planWithJSONObject:(id)object error:(NSError **)error
{
    if (![object isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [NSError errorWithDomain:ATTapPlanErrorDomain
                                         code:ATTapPlanErrorCodeInvalidJSON
                                     userInfo:@{NSLocalizedDescriptionKey : @"方案 JSON 不是字典类型"}];
        }
        return nil;
    }

    NSDictionary *dict = (NSDictionary *)object;

    NSString *name = nil;
    id nameObj = dict[@"name"];
    if ([nameObj isKindOfClass:[NSString class]] && ((NSString *)nameObj).length > 0) {
        name = (NSString *)nameObj;
    } else {
        name = @"未命名方案";
    }

    NSInteger loopCount = 1;
    id loopObj = dict[@"loopCount"];
    if ([loopObj isKindOfClass:[NSNumber class]]) {
        loopCount = ((NSNumber *)loopObj).integerValue;
    }

    NSMutableArray<ATTapStep *> *steps = [NSMutableArray array];
    id stepsObj = dict[@"steps"];
    if ([stepsObj isKindOfClass:[NSArray class]]) {
        for (id stepObj in (NSArray *)stepsObj) {
            NSError *stepError = nil;
            ATTapStep *step = [ATTapStep stepWithJSONObject:stepObj error:&stepError];
            if (!step) {
                if (error) {
                    *error = stepError ?: [NSError errorWithDomain:ATTapPlanErrorDomain
                                                             code:ATTapPlanErrorCodeInvalidJSON
                                                         userInfo:@{NSLocalizedDescriptionKey : @"步骤解析失败"}];
                }
                return nil;
            }
            [steps addObject:step];
        }
    }

    return [[ATTapPlan alloc] initWithName:name loopCount:loopCount steps:steps];
}

@end

