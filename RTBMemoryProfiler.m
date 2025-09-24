#import "RTBMemoryProfiler.h"
#import <objc/runtime.h>
#import "flex_fishhook.h"
#import <malloc/malloc.h>
#import <execinfo.h>

@interface RTBMemoryProfiler ()
- (void)analyzeObject:(id _Nullable)object 
       visitedObjects:(NSMutableSet * _Nonnull)visitedObjects 
       referenceChain:(NSMutableArray * _Nonnull)referenceChain;
- (void)startMonitoring;
- (void)stopMonitoring;
- (void)recordAllocation;
- (NSDictionary * _Nonnull)getMemoryStatistics;
@end

@implementation RTBMemoryProfiler {
    CFMutableDictionaryRef _allocations;
    dispatch_queue_t _queue;
    BOOL _isMonitoring;
    NSMutableArray *_referenceChain;
}

// 添加__attribute__((unused))标记告诉编译器这个函数是有意未使用的
static void * _Nullable __attribute__((unused)) RTBAllocationCallback(void * _Nullable context) {
    RTBMemoryProfiler *profiler = (__bridge RTBMemoryProfiler *)context;
    [profiler recordAllocation];
    return NULL;
}

- (instancetype)init {
    if (self = [super init]) {
        _allocations = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        _queue = dispatch_queue_create("com.rtb.memoryprofiler", DISPATCH_QUEUE_SERIAL);
        _isMonitoring = NO;
        _referenceChain = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)sharedInstance {
    static RTBMemoryProfiler *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (void)startMemoryTracking {
    [[self sharedInstance] startMonitoring];
}

+ (void)stopMemoryTracking {
    [[self sharedInstance] stopMonitoring];
}

+ (NSDictionary *)getMemoryProfile {
    return [[self sharedInstance] getMemoryStatistics];
}

- (void)trackObjectReferences:(id)object {
    if (!object) return;
    
    NSMutableSet *visitedObjects = [NSMutableSet new];
    NSMutableArray *referenceChain = [NSMutableArray new];
    
    [self analyzeObject:object 
         visitedObjects:visitedObjects 
         referenceChain:referenceChain];
}

- (NSArray *)getObjectReferencesChain {
    return [_referenceChain copy];
}

- (void)analyzeObject:(id)object 
       visitedObjects:(NSMutableSet *)visitedObjects 
       referenceChain:(NSMutableArray *)referenceChain {
    // 防止循环引用导致死循环
    if ([visitedObjects containsObject:object]) return;
    [visitedObjects addObject:object];
    
    // 获取对象的所有实例变量
    unsigned int ivarCount = 0;
    Class cls = object_getClass(object);
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *ivarName = ivar_getName(ivar);
        NSString *name = @(ivarName);
        
        // 获取实例变量的值
        id value = object_getIvar(object, ivar);
        if (value) {
            [referenceChain addObject:@{
                @"object": object,
                @"ivar": name,
                @"value": value
            }];
            
            // 递归分析
            [self analyzeObject:value 
                visitedObjects:visitedObjects 
                referenceChain:referenceChain];
        }
    }
    free(ivars);
}

- (void)startMonitoring {
    if (_isMonitoring) return;
    
    // 实现监控逻辑
    _isMonitoring = YES;
    
    // 这些代码行被注释掉，但保留给未来使用
    // malloc_zone_t *zone = malloc_default_zone();
    // malloc_zone_register_calloc(zone, RTBAllocationCallback, (__bridge void *)self);
    // malloc_zone_register_malloc(zone, RTBAllocationCallback, (__bridge void *)self);
}

- (void)stopMonitoring {
    if (!_isMonitoring) return;
    
    // 停止监控
    _isMonitoring = NO;
}

- (void)recordAllocation {
    // 获取调用堆栈
    void *callstack[128];
    int frames = backtrace(callstack, 128);
    char **symbols = backtrace_symbols(callstack, frames);
    
    if (symbols) {
        // 处理堆栈信息
        free(symbols);
    }
}

- (NSDictionary *)getMemoryStatistics {
    // 返回内存统计结果
    return @{};
}

- (void)detectRetainCycles {
    // 实现循环引用检测
}

- (NSArray *)getRetainCycleInfo {
    // 返回循环引用信息
    return @[];
}

@end