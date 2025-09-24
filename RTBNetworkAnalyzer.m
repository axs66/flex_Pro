#import "RTBNetworkAnalyzer.h"

@interface RTBNetworkAnalyzer()
@property (nonatomic, strong) NSMutableArray *requests;
@end

@implementation RTBNetworkAnalyzer

+ (instancetype)sharedAnalyzer {
    static RTBNetworkAnalyzer *sharedAnalyzer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedAnalyzer = [[self alloc] init];
    });
    return sharedAnalyzer;
}

- (instancetype)init {
    if (self = [super init]) {
        _requests = [NSMutableArray array];
    }
    return self;
}

- (NSDictionary *)getNetworkStatistics {
    return @{
        @"totalRequests": @(self.requests.count),
        @"avgResponseTime": @(0.5), // 示例数据
        @"totalDataSent": @(1024), // 示例数据，单位KB
        @"totalDataReceived": @(2048) // 示例数据，单位KB
    };
}

- (NSArray *)getAllRequests {
    return [self.requests copy];
}

@end