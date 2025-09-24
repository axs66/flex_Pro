#import "RTBMethodTracker.h"
#import "NSObject+RuntimeBrowser.h"
#import <objc/runtime.h>
#import <objc/message.h>

// 最大存储的调用记录数
static const NSInteger kMaxTrackedCalls = 1000;

@implementation RTBMethodTrackerRecord
@end

@interface RTBMethodTracker ()

@property (nonatomic, strong) NSMutableArray<RTBMethodTrackerRecord *> *callRecords;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *trackedClasses;
@property (nonatomic, strong) NSLock *recordsLock;
@property (nonatomic, strong) dispatch_queue_t trackingQueue;
@property (nonatomic, assign) int callDepth;

// 添加之前第二个实现中使用的属性
@property (nonatomic, strong) NSMutableDictionary *trackedMethods;
@property (nonatomic, strong) NSMutableArray *callStack;

@end

@implementation RTBMethodTracker

+ (instancetype)sharedTracker {
    static RTBMethodTracker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _callRecords = [NSMutableArray array];
        _trackedClasses = [NSMutableDictionary dictionary];
        _recordsLock = [[NSLock alloc] init];
        _trackingQueue = dispatch_queue_create("com.runtimebrowser.methodtracker", DISPATCH_QUEUE_SERIAL);
        _callDepth = 0;
        _trackedMethods = [NSMutableDictionary dictionary];
        _callStack = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Public API

- (void)startTrackingClass:(Class)cls {
    NSString *className = NSStringFromClass(cls);
    
    [self.recordsLock lock];
    if (!self.trackedClasses[className]) {
        self.trackedClasses[className] = [NSMutableSet set];
    }
    [self.recordsLock unlock];
    
    [self swizzleMethodsForClass:cls];
}

- (void)stopTrackingClass:(Class)cls {
    NSString *className = NSStringFromClass(cls);
    
    [self.recordsLock lock];
    [self.trackedClasses removeObjectForKey:className];
    [self.recordsLock unlock];
    
    // 理想情况下应该取消swizzle，但这比较复杂，这里简化处理
}

- (void)startTrackingClassesWithPrefix:(NSString *)prefix {
    if (!prefix.length) return;
    
    unsigned int classCount = 0;
    Class *classList = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        NSString *className = NSStringFromClass(classList[i]);
        if ([className hasPrefix:prefix]) {
            [self startTrackingClass:classList[i]];
        }
    }
    
    free(classList);
}

- (void)stopTrackingAllClasses {
    [self.recordsLock lock];
    [self.trackedClasses removeAllObjects];
    [self.recordsLock unlock];
}

- (NSArray<RTBMethodTrackerRecord *> *)recentCalls {
    [self.recordsLock lock];
    NSArray<RTBMethodTrackerRecord *> *calls = [self.callRecords copy];
    [self.recordsLock unlock];
    return calls;
}

- (NSArray<RTBMethodTrackerRecord *> *)callsForClass:(Class)cls {
    NSString *className = NSStringFromClass(cls);
    NSMutableArray<RTBMethodTrackerRecord *> *result = [NSMutableArray array];
    
    [self.recordsLock lock];
    for (RTBMethodTrackerRecord *record in self.callRecords) {
        if ([record.className isEqualToString:className]) {
            [result addObject:record];
        }
    }
    [self.recordsLock unlock];
    
    return result;
}

- (NSArray<RTBMethodTrackerRecord *> *)callsWithDurationAbove:(NSTimeInterval)threshold {
    [self.recordsLock lock];
    NSMutableArray<RTBMethodTrackerRecord *> *result = [NSMutableArray array];
    for (RTBMethodTrackerRecord *record in self.callRecords) {
        if (record.duration >= threshold) {
            [result addObject:record];
        }
    }
    [self.recordsLock unlock];
    
    return result;
}

- (NSDictionary<NSString *, NSNumber *> *)callCountByClass {
    [self.recordsLock lock];
    NSMutableDictionary<NSString *, NSNumber *> *counts = [NSMutableDictionary dictionary];
    
    for (RTBMethodTrackerRecord *record in self.callRecords) {
        NSNumber *count = counts[record.className] ?: @0;
        counts[record.className] = @(count.integerValue + 1);
    }
    
    [self.recordsLock unlock];
    return [counts copy];
}

- (NSDictionary<NSString *, NSNumber *> *)averageDurationByMethod {
    NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *durations = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSNumber *> *result = [NSMutableDictionary dictionary];
    
    [self.recordsLock lock];
    for (RTBMethodTrackerRecord *record in self.callRecords) {
        NSString *key = [NSString stringWithFormat:@"%@.%@", record.className, record.methodName];
        
        if (!durations[key]) {
            durations[key] = [NSMutableArray array];
        }
        [durations[key] addObject:@(record.duration)];
    }
    [self.recordsLock unlock];
    
    [durations enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSMutableArray<NSNumber *> *values, BOOL *stop) {
        double sum = 0;
        for (NSNumber *duration in values) {
            sum += duration.doubleValue;
        }
        
        result[key] = @(sum / values.count);
    }];
    
    return result;
}

- (NSArray<NSString *> *)mostCalledMethods {
    NSMutableDictionary<NSString *, NSNumber *> *methodCounts = [NSMutableDictionary dictionary];
    
    [self.recordsLock lock];
    for (RTBMethodTrackerRecord *record in self.callRecords) {
        NSString *key = [NSString stringWithFormat:@"%@.%@", record.className, record.methodName];
        
        NSNumber *count = methodCounts[key] ?: @0;
        methodCounts[key] = @(count.integerValue + 1);
    }
    [self.recordsLock unlock];
    
    NSArray<NSString *> *methods = [methodCounts keysSortedByValueUsingComparator:^NSComparisonResult(NSNumber *obj1, NSNumber *obj2) {
        return [obj2 compare:obj1]; // 降序排列
    }];
    
    // 返回前20个最常调用的方法
    NSUInteger count = MIN(methods.count, 20);
    return [methods subarrayWithRange:NSMakeRange(0, count)];
}

#pragma mark - Private methods

- (void)swizzleMethodsForClass:(Class)cls {
    // 获取实例方法
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    NSString *className = NSStringFromClass(cls);
    [self.recordsLock lock];
    NSMutableSet<NSString *> *trackedMethods = self.trackedClasses[className];
    [self.recordsLock unlock];
    
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL selector = method_getName(methods[i]);
        NSString *methodName = NSStringFromSelector(selector);
        
        // 跳过系统方法、setters和getters以减少噪声
        if ([methodName hasPrefix:@"."] || 
            [methodName hasPrefix:@"_"] || 
            [methodName isEqualToString:@"dealloc"] ||
            [methodName isEqualToString:@"retain"] ||
            [methodName isEqualToString:@"release"] ||
            [methodName isEqualToString:@"autorelease"]) {
            continue;
        }
        
        // 检查是否已经跟踪了该方法
        if ([trackedMethods containsObject:methodName]) {
            continue;
        }
        
        // 创建动态子类并swizzle方法
        [self swizzleMethod:selector forClass:cls isClassMethod:NO];
        [trackedMethods addObject:methodName];
    }
    
    free(methods);
    
    // 获取类方法
    methodCount = 0;
    methods = class_copyMethodList(object_getClass(cls), &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL selector = method_getName(methods[i]);
        NSString *methodName = NSStringFromSelector(selector);
        
        // 跳过系统方法
        if ([methodName hasPrefix:@"."] || 
            [methodName hasPrefix:@"_"] ||
            [methodName isEqualToString:@"initialize"] ||
            [methodName isEqualToString:@"load"]) {
            continue;
        }
        
        // 检查是否已经跟踪了该方法
        NSString *classMethodName = [NSString stringWithFormat:@"+%@", methodName];
        if ([trackedMethods containsObject:classMethodName]) {
            continue;
        }
        
        // 创建动态子类并swizzle方法
        [self swizzleMethod:selector forClass:cls isClassMethod:YES];
        [trackedMethods addObject:classMethodName];
    }
    
    free(methods);
}

- (void)swizzleMethod:(SEL)selector forClass:(Class)cls isClassMethod:(BOOL)isClassMethod {
    Class targetClass = isClassMethod ? object_getClass(cls) : cls;
    NSString *className = NSStringFromClass(cls);
    NSString *methodName = NSStringFromSelector(selector);
    
    if (isClassMethod) {
        methodName = [NSString stringWithFormat:@"+%@", methodName];
    }
    
    // 创建跟踪方法
    Method originalMethod = class_getInstanceMethod(targetClass, selector);
    const char *typeEncoding = method_getTypeEncoding(originalMethod);
    
    // 创建新的实现，包装原始实现
    IMP newIMP = imp_implementationWithBlock(^(id self, ...) {
        RTBMethodTracker *tracker = [RTBMethodTracker sharedTracker];
        NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
        int depth = tracker.callDepth++;
        
        // 准备参数并调用原始方法
        NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:typeEncoding];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.selector = selector;
        invocation.target = self;
        
        // 设置参数 - 注意：这是简化版，不处理复杂参数
        va_list args;
        va_start(args, self);
        for (NSUInteger i = 2; i < signature.numberOfArguments; i++) {
            // 这里需要根据参数类型正确处理，但为简化代码，我们只处理基本类型
            void *arg = va_arg(args, void *);
            [invocation setArgument:&arg atIndex:i];
        }
        va_end(args);
        
        [invocation invoke];
        
        // 计算执行时间
        NSTimeInterval endTime = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval duration = endTime - startTime;
        
        // 记录方法调用
        RTBMethodTrackerRecord *record = [[RTBMethodTrackerRecord alloc] init];
        record.className = className;
        record.methodName = methodName;
        record.isClassMethod = isClassMethod;
        record.timestamp = startTime;
        record.duration = duration;
        record.depth = depth;
        
        tracker.callDepth--;
        
        dispatch_async(tracker.trackingQueue, ^{
            [tracker recordMethodCall:record];
        });
        
        // 返回结果
        if (signature.methodReturnLength > 0) {
            void *returnValue = malloc(signature.methodReturnLength);
            [invocation getReturnValue:returnValue];
            void *result = returnValue;
            free(returnValue);
            return result;
        }
        return NULL;
    });
    
    // 替换原始方法
    if (!class_addMethod(targetClass, selector, newIMP, typeEncoding)) {
        method_setImplementation(originalMethod, newIMP);
    }
}

- (void)recordMethodCall:(RTBMethodTrackerRecord *)record {
    [self.recordsLock lock];
    
    [self.callRecords addObject:record];
    
    // 限制记录数量
    if (self.callRecords.count > kMaxTrackedCalls) {
        [self.callRecords removeObjectsInRange:NSMakeRange(0, self.callRecords.count - kMaxTrackedCalls)];
    }
    
    [self.recordsLock unlock];
}

@end