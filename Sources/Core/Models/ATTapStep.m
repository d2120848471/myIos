#import "ATTapStep.h"

static NSString *const ATTapStepErrorDomain = @"com.autotap.ATTapStep";

typedef NS_ENUM(NSInteger, ATTapStepErrorCode) {
    ATTapStepErrorCodeInvalidJSON = 1,
};

@implementation ATTapStep

- (instancetype)initWithPoint:(CGPoint)point delayMs:(NSInteger)delayMs
{
    self = [super init];
    if (self) {
        _point = point;
        _delayMs = MAX(0, delayMs);
    }
    return self;
}

- (NSDictionary *)jsonObject
{
    return @{
        @"x": @(_point.x),
        @"y": @(_point.y),
        @"delayMs": @(_delayMs),
    };
}

+ (instancetype)stepWithJSONObject:(id)object error:(NSError **)error
{
    if (![object isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [NSError errorWithDomain:ATTapStepErrorDomain
                                         code:ATTapStepErrorCodeInvalidJSON
                                     userInfo:@{NSLocalizedDescriptionKey : @"步骤 JSON 不是字典类型"}];
        }
        return nil;
    }

    NSDictionary *dict = (NSDictionary *)object;
    NSNumber *xNumber = dict[@"x"];
    NSNumber *yNumber = dict[@"y"];
    NSNumber *delayMsNumber = dict[@"delayMs"];

    if (![xNumber isKindOfClass:[NSNumber class]] || ![yNumber isKindOfClass:[NSNumber class]]) {
        if (error) {
            *error = [NSError errorWithDomain:ATTapStepErrorDomain
                                         code:ATTapStepErrorCodeInvalidJSON
                                     userInfo:@{NSLocalizedDescriptionKey : @"步骤 JSON 缺少 x/y 或类型错误"}];
        }
        return nil;
    }

    NSInteger delayMs = 0;
    if ([delayMsNumber isKindOfClass:[NSNumber class]]) {
        delayMs = delayMsNumber.integerValue;
    }

    return [[ATTapStep alloc] initWithPoint:CGPointMake(xNumber.doubleValue, yNumber.doubleValue) delayMs:delayMs];
}

@end

