@interface RTBMethodMonitor : NSObject

+ (instancetype)sharedInstance;

// 开始监控指定类的方法调用
- (void)startMonitoringClass:(Class)cls;

// 停止监控指定类的方法调用
- (void)stopMonitoringClass:(Class)cls;

// 获取方法调用统计信息
- (NSDictionary *)getMethodCallStatistics;

@end

// filepath: /Users/pxx917144686/Downloads/DYYY/RuntimeBrowser/RTBMethodMonitor.m

@implementation RTBMethodMonitor {
    NSMutableDictionary *_methodCallCounts;
    NSMutableDictionary *_methodExecutionTimes;
    dispatch_queue_t _queue;
}

+ (instancetype)sharedInstance {
    static RTBMethodMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RTBMethodMonitor alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _methodCallCounts = [NSMutableDictionary new];
        _methodExecutionTimes = [NSMutableDictionary new];
        _queue = dispatch_queue_create("com.rtb.methodmonitor", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)startMonitoringClass:(Class)cls {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        
        // 保存原始实现
        IMP originalImp = method_getImplementation(method);
        const char *typeEncoding = method_getTypeEncoding(method);
        
        // 创建新的实现
        IMP newImp = imp_implementationWithBlock(^(id self, ...) {
            NSString *methodKey = [NSString stringWithFormat:@"%@[%@ %@]",
                                 NSStringFromClass(cls),
                                 cls_isMetaClass(object_getClass(self)) ? @"+" : @"-",
                                 NSStringFromSelector(selector)];
            
            // 记录调用次数
            dispatch_async(_queue, ^{
                NSNumber *count = _methodCallCounts[methodKey];
                _methodCallCounts[methodKey] = @(count.integerValue + 1);
            });
            
            // 记录执行时间
            CFTimeInterval startTime = CACurrentMediaTime();
            
            // 调用原始方法
            void *result = nil;
            NSMethodSignature *signature = [cls instanceMethodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:self];
            [invocation setSelector:selector];
            [invocation invoke];
            [invocation getReturnValue:&result];
            
            CFTimeInterval endTime = CACurrentMediaTime();
            
            // 更新执行时间
            dispatch_async(_queue, ^{
                NSNumber *totalTime = _methodExecutionTimes[methodKey];
                _methodExecutionTimes[methodKey] = @(totalTime.doubleValue + (endTime - startTime));
            });
            
            return result;
        });
        
        // 替换方法实现
        class_replaceMethod(cls, selector, newImp, typeEncoding);
    }
    
    free(methods);
}

@end