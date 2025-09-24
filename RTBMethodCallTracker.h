#import <Foundation/Foundation.h>

@interface RTBMethodCallTracker : NSObject

// 方法调用追踪
+ (void)startMethodCallTracking;
+ (void)stopMethodCallTracking;
+ (NSDictionary *)getMethodCallStatistics;

// 添加方法调用堆栈追踪
- (void)enableCallStackTracking;
- (NSArray *)getMethodCallStacks;

// 方法调用频率分析
- (void)analyzeMethodCallFrequency;
- (NSDictionary *)getMethodCallFrequencyReport;

@end