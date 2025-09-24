@interface RTBCore : NSObject

// 单例方法
+ (instancetype)sharedInstance;

// 核心分析功能
@property (nonatomic, strong) RTBRuntime *runtime;
@property (nonatomic, strong) RTBMemoryProfiler *memoryProfiler;
@property (nonatomic, strong) RTBMethodCallTracker *methodTracker;
@property (nonatomic, strong) RTBClassAnalyzer *classAnalyzer;

// 功能开关
- (void)startAllAnalysis;
- (void)stopAllAnalysis;

// 结果获取
- (NSDictionary *)getAllAnalysisResults;

@end