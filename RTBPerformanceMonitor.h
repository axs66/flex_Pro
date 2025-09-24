#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface RTBPerformanceMetrics : NSObject
@property (nonatomic, assign) CGFloat cpuUsage;
@property (nonatomic, assign) CGFloat memoryUsage;
@property (nonatomic, assign) CGFloat fps;
@property (nonatomic, assign) NSTimeInterval timestamp;
@end

@interface RTBPerformanceMonitor : NSObject

+ (instancetype)sharedInstance;

// 性能监控
- (void)startPerformanceMonitoring;
- (void)stopPerformanceMonitoring;

// 获取性能数据
- (RTBPerformanceMetrics *)getCurrentMetrics;
- (NSArray<RTBPerformanceMetrics *> *)getMetricsHistory;

// UI性能检测
- (void)startUIPerformanceDetection;
- (NSArray *)getLargeImageDetectionResults;
- (NSArray *)getViewDepthAnalysis;

@end