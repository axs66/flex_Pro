#import <Foundation/Foundation.h>
#import "RTBHookManager.h"
#import "RTBNetworkMonitor.h"
#import "RTBPerformanceMonitor.h"
#import "RTBViewHierarchyAnalyzer.h"
#import "RTBMemoryLeakDetector.h"

@interface RTBDoKitIntegration : NSObject

+ (instancetype)sharedInstance;

// 一键启动所有DoKit功能
- (void)startAllDoKitFeatures;
- (void)stopAllDoKitFeatures;

// 获取综合分析报告
- (NSDictionary *)getComprehensiveAnalysisReport;

// 导出分析数据
- (BOOL)exportAnalysisDataToPath:(NSString *)path;

@end