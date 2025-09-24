#import "RTBDoKitIntegration.h"

@implementation RTBDoKitIntegration

+ (instancetype)sharedInstance {
    static RTBDoKitIntegration *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RTBDoKitIntegration alloc] init];
    });
    return instance;
}

- (void)startAllDoKitFeatures {
    // 启动所有DoKit增强功能
    [[RTBHookManager sharedInstance] startMethodCallMonitoring];
    [[RTBNetworkMonitor sharedInstance] startNetworkMonitoring];
    [[RTBPerformanceMonitor sharedInstance] startPerformanceMonitoring];
    [[RTBMemoryLeakDetector sharedInstance] startLeakDetection];
    
    NSLog(@"RTBDoKitIntegration: 所有DoKit功能已启动");
}

// 添加缺少的方法实现
- (void)stopAllDoKitFeatures {
    // 停止所有DoKit增强功能
    [[RTBHookManager sharedInstance] stopMethodCallMonitoring];
    [[RTBNetworkMonitor sharedInstance] stopNetworkMonitoring];
    [[RTBPerformanceMonitor sharedInstance] stopPerformanceMonitoring];
    [[RTBMemoryLeakDetector sharedInstance] stopLeakDetection];
    
    NSLog(@"RTBDoKitIntegration: 所有DoKit功能已停止");
}

- (NSDictionary *)getComprehensiveAnalysisReport {
    NSMutableDictionary *report = [NSMutableDictionary dictionary];
    
    // 网络分析
    report[@"networkRequests"] = [[RTBNetworkMonitor sharedInstance] getAllNetworkRequests];
    
    // 性能指标
    report[@"performanceMetrics"] = [[RTBPerformanceMonitor sharedInstance] getMetricsHistory];
    
    // Hook记录
    report[@"hookedMethods"] = [[RTBHookManager sharedInstance] getAllHookedMethods];
    
    // 内存泄漏
    report[@"memoryLeaks"] = [[RTBMemoryLeakDetector sharedInstance] getLeakRecords];
    
    // 生成时间戳
    report[@"generatedAt"] = @([[NSDate date] timeIntervalSince1970]);
    
    return report;
}

// 添加缺少的方法实现
- (BOOL)exportAnalysisDataToPath:(NSString *)path {
    if (!path) {
        return NO;
    }
    
    // 获取完整的分析报告
    NSDictionary *report = [self getComprehensiveAnalysisReport];
    
    // 检查目录是否存在，如果不存在则创建
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *directoryPath = [path stringByDeletingLastPathComponent];
    
    NSError *error = nil;
    if (![fileManager fileExistsAtPath:directoryPath]) {
        [fileManager createDirectoryAtPath:directoryPath 
               withIntermediateDirectories:YES 
                                attributes:nil 
                                     error:&error];
        if (error) {
            NSLog(@"创建目录失败: %@", error.localizedDescription);
            return NO;
        }
    }
    
    // 将报告导出为JSON文件
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:report 
                                                       options:NSJSONWritingPrettyPrinted 
                                                         error:&error];
    if (error) {
        NSLog(@"序列化数据失败: %@", error.localizedDescription);
        return NO;
    }
    
    BOOL success = [jsonData writeToFile:path options:NSDataWritingAtomic error:&error];
    if (!success) {
        NSLog(@"写入文件失败: %@", error.localizedDescription);
        return NO;
    }
    
    return YES;
}

@end