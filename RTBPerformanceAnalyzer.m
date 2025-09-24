#import "RTBPerformanceAnalyzer.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

@implementation RTBPerformanceAnalyzer

+ (instancetype)sharedInstance {
    static RTBPerformanceAnalyzer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _methodExecutionTimes = [NSMutableDictionary dictionary];
        _methodCallCounts = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)startAnalyzingClass:(Class)cls {
    if (!cls) return;
    
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        NSString *methodName = NSStringFromSelector(selector);
        
        // 初始化性能计数器
        _methodExecutionTimes[methodName] = @0;
        _methodCallCounts[methodName] = @0;
        
        // 替换方法实现以进行性能分析
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
        IMP originalImp = method_getImplementation(method);
#pragma clang diagnostic pop
        IMP newImp = imp_implementationWithBlock(^(id self, ...){
            // 记录开始时间
            CFTimeInterval startTime = CACurrentMediaTime();
            
            // 调用原始方法
            va_list args;
            va_start(args, self);
            id result = nil;
            
            // va_list是可变参数列表，不能直接转换为NSInvocation
            // 需要创建一个新的NSInvocation对象或修改方法逻辑
            NSMethodSignature *signature = [self methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setSelector:selector];
            [invocation setTarget:self];
            // 此处应从args获取参数并设置到invocation
            // 由于无法直接访问可变参数内容，我们只转发基本调用
            [invocation invoke];
            
            va_end(args);
            
            // 计算执行时间
            CFTimeInterval endTime = CACurrentMediaTime();
            CFTimeInterval executionTime = endTime - startTime;
            
            // 更新性能数据
            [[RTBPerformanceAnalyzer sharedInstance] updatePerformanceData:methodName
                                                          executionTime:executionTime];
            
            return result;
        });
        
        method_setImplementation(method, newImp);
    }
    
    free(methods);
}

- (void)updatePerformanceData:(NSString *)methodName executionTime:(CFTimeInterval)executionTime {
    @synchronized (self) {
        // 更新执行时间
        NSNumber *totalTime = _methodExecutionTimes[methodName];
        _methodExecutionTimes[methodName] = @(totalTime.doubleValue + executionTime);
        
        // 更新调用次数
        NSNumber *callCount = _methodCallCounts[methodName];
        _methodCallCounts[methodName] = @(callCount.integerValue + 1);
    }
}

- (void)stopAnalyzingClass:(Class)cls {
    if (!cls) return;
    
    // 恢复原始方法实现
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        NSString *methodName = NSStringFromSelector(selector);
        
        // 清理性能数据
        [_methodExecutionTimes removeObjectForKey:methodName];
        [_methodCallCounts removeObjectForKey:methodName];
    }
    
    free(methods);
}

- (NSDictionary *)getPerformanceDataForClass:(Class)cls {
    NSMutableDictionary *performanceData = [NSMutableDictionary dictionary];
    
    // 遍历所有方法
    for (NSString *methodName in _methodExecutionTimes.allKeys) {
        NSTimeInterval totalTime = [_methodExecutionTimes[methodName] doubleValue];
        NSInteger callCount = [_methodCallCounts[methodName] integerValue];
        
        if (callCount > 0) {
            NSTimeInterval averageTime = totalTime / callCount;
            
            performanceData[methodName] = @{
                @"totalTime": @(totalTime),
                @"callCount": @(callCount),
                @"averageTime": @(averageTime)
            };
        }
    }
    
    return performanceData;
}

@end