#import "RTBPerformanceMonitor.h"
#import "UIViewController+DoraemonUIProfile.h"
#import <sys/sysctl.h>
#import <mach/mach.h>

@implementation RTBPerformanceMetrics
@end

@interface RTBPerformanceMonitor ()
@property (nonatomic, strong) NSTimer *monitorTimer;
@property (nonatomic, strong) NSMutableArray<RTBPerformanceMetrics *> *metricsHistory;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) NSTimeInterval lastTimestamp;
@property (nonatomic, assign) NSInteger frameCount;
@property (nonatomic, assign) CGFloat currentFPS;

// 声明缺少的方法
- (void)startFPSMonitoring;
- (void)stopFPSMonitoring;
- (CGFloat)getCurrentCPUUsage;
- (CGFloat)getCurrentMemoryUsage;
- (CGFloat)getCurrentFPS;
- (void)enableLargeImageDetection;
@end

@implementation RTBPerformanceMonitor

+ (instancetype)sharedInstance {
    static RTBPerformanceMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RTBPerformanceMonitor alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _metricsHistory = [NSMutableArray array];
    }
    return self;
}

- (void)startPerformanceMonitoring {
    if (self.monitorTimer) return;
    
    // 启动性能监控定时器
    self.monitorTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(collectMetrics)
                                                       userInfo:nil
                                                        repeats:YES];
    
    // 启动FPS监控
    [self startFPSMonitoring];
}

- (void)collectMetrics {
    RTBPerformanceMetrics *metrics = [[RTBPerformanceMetrics alloc] init];
    metrics.cpuUsage = [self getCurrentCPUUsage];
    metrics.memoryUsage = [self getCurrentMemoryUsage];
    metrics.fps = [self getCurrentFPS];
    metrics.timestamp = [[NSDate date] timeIntervalSince1970];
    
    [self.metricsHistory addObject:metrics];
    
    // 保持最近100条记录
    if (self.metricsHistory.count > 100) {
        [self.metricsHistory removeObjectAtIndex:0];
    }
}

// 实现缺少的方法
- (void)stopPerformanceMonitoring {
    [self.monitorTimer invalidate];
    self.monitorTimer = nil;
    
    // 停止FPS监控
    [self stopFPSMonitoring];
}

- (RTBPerformanceMetrics *)getCurrentMetrics {
    RTBPerformanceMetrics *metrics = [[RTBPerformanceMetrics alloc] init];
    metrics.cpuUsage = [self getCurrentCPUUsage];
    metrics.memoryUsage = [self getCurrentMemoryUsage];
    metrics.fps = [self getCurrentFPS];
    metrics.timestamp = [[NSDate date] timeIntervalSince1970];
    return metrics;
}

- (NSArray<RTBPerformanceMetrics *> *)getMetricsHistory {
    return [self.metricsHistory copy];
}

- (CGFloat)getCurrentCPUUsage {
    // 参考DoKit的CPU使用率获取方法
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count;
    
    task_info_count = TASK_INFO_MAX;
    kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        return 0.0;
    }
    
    thread_array_t thread_list;
    mach_msg_type_number_t thread_count;
    
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return 0.0;
    }
    
    float tot_cpu = 0;
    
    for (int j = 0; j < thread_count; j++) {
        thread_info_data_t thinfo;
        mach_msg_type_number_t thread_info_count = THREAD_INFO_MAX;
        kr = thread_info(thread_list[j], THREAD_BASIC_INFO, (thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            continue;
        }
        
        thread_basic_info_t basic_info_th = (thread_basic_info_t)thinfo;
        
        if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
            tot_cpu += basic_info_th->cpu_usage / (float)TH_USAGE_SCALE;
        }
    }
    
    // 释放内存
    vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
    
    return tot_cpu * 100.0;
}

- (CGFloat)getCurrentMemoryUsage {
    mach_task_basic_info_data_t taskInfo;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    
    kern_return_t result = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&taskInfo, &count);
    
    if (result != KERN_SUCCESS) {
        return 0.0;
    }
    
    // 转换为MB
    return taskInfo.resident_size / (1024.0 * 1024.0);
}

- (void)startFPSMonitoring {
    if (self.displayLink) return;
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkTick:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    self.lastTimestamp = CACurrentMediaTime();
    self.frameCount = 0;
}

- (void)stopFPSMonitoring {
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)displayLinkTick:(CADisplayLink *)link {
    self.frameCount++;
    
    NSTimeInterval now = CACurrentMediaTime();
    NSTimeInterval delta = now - self.lastTimestamp;
    
    if (delta >= 1.0) {
        self.currentFPS = self.frameCount / delta;
        self.frameCount = 0;
        self.lastTimestamp = now;
    }
}

- (CGFloat)getCurrentFPS {
    return self.currentFPS;
}

- (void)startUIPerformanceDetection {
    // 启动Doraemon UI性能监控
    [UIViewController startDoraemonUIProfileMonitoring];
    
    // 启用大图检测
    [self enableLargeImageDetection];
}

- (void)enableLargeImageDetection {
    // 实现大图检测逻辑
    NSLog(@"开启大图检测");
}

- (NSArray *)getLargeImageDetectionResults {
    // 返回大图检测结果
    return @[];
}

- (NSArray *)getViewDepthAnalysis {
    // 返回视图层次分析结果
    return @[];
}

@end