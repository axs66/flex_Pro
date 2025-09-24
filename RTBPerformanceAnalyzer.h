#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

@interface RTBPerformanceAnalyzer : NSObject

@property (nonatomic, strong) NSMutableDictionary *methodExecutionTimes;
@property (nonatomic, strong) NSMutableDictionary *methodCallCounts;

+ (instancetype)sharedInstance;
- (void)startAnalyzingClass:(Class)cls;
- (void)stopAnalyzingClass:(Class)cls;
- (NSDictionary *)getPerformanceDataForClass:(Class)cls;
- (void)updatePerformanceData:(NSString *)methodName executionTime:(CFTimeInterval)executionTime;

@end