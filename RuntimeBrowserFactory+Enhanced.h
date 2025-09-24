#import "RuntimeBrowserFactory.h"

@interface RuntimeBrowserFactory (Enhanced)

// 方法执行时间分析
+ (void)startMethodProfiler;
+ (void)stopMethodProfiler;
+ (NSArray<NSDictionary *> *)getProfiledMethodResults;

// 类层次结构详细分析
+ (NSDictionary *)getDetailedClassHierarchyForClass:(Class)cls;

// 实时对象监控
+ (void)startMonitoringObject:(id)object;
+ (void)stopMonitoringObject:(id)object;

// 网络请求监控
+ (void)startNetworkMonitoring;
+ (void)stopNetworkMonitoring;
+ (NSArray *)getCurrentNetworkRequests;

// 内存泄漏检测
+ (void)startMemoryLeakDetection;
+ (void)stopMemoryLeakDetection;
+ (NSArray *)getDetectedMemoryLeaks;

// 动态方法调用
+ (id)invokeMethod:(SEL)selector onObject:(id)target withArguments:(NSArray *)arguments;

// UI元素信息可视化
+ (void)startUIInspecting;
+ (void)stopUIInspecting;

@end