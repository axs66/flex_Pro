#import <Foundation/Foundation.h>

@interface RTBClassPerformanceAnalyzer : NSObject

// 分析类的方法调用次数
+ (NSDictionary *)analyzeMethodCallsForClass:(Class)cls;

// 分析类的内存占用
+ (NSDictionary *)analyzeMemoryUsageForClass:(Class)cls;

// 分析类的属性访问频次
+ (NSDictionary *)analyzePropertyAccessForClass:(Class)cls;

@end