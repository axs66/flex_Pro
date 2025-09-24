#import <Foundation/Foundation.h>
#import "RTBMethodProfiler.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#import "flex_fishhook.h"
#import <pthread/pthread.h>
#import <objc/message.h>

static id (*orig_objc_msgSend)(id, SEL, ...);
static pthread_key_t _thread_key;
static bool _profiling_enabled = NO;

typedef struct {
    id self;
    Class cls;
    SEL cmd; 
    uint64_t time; // us
    int depth;
} rtb_call_record;

typedef struct {
    rtb_call_record *stack;
    int allocated_length;
    int index;
    bool is_main_thread;
} thread_call_stack;

static void release_thread_call_stack(void *ptr) {
    if (ptr) {
        thread_call_stack *stack = (thread_call_stack *)ptr;
        if (stack->stack) {
            free(stack->stack);
        }
        free(stack);
    }
}

static void *replacement_objc_msgSend(id self, SEL _cmd, ...) {
    // 简单实现，实际项目中可能需要更复杂的逻辑
    if (!self || !_cmd) return NULL;
    
    // 获取原始实现，添加桥接转换
    return (__bridge void *)orig_objc_msgSend(self, _cmd);
}

@implementation RTBMethodProfiler

+ (instancetype)sharedInstance {
    static RTBMethodProfiler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _methodCallStats = [NSMutableDictionary dictionary];
        _isRecording = NO;
    }
    return self;
}

- (void)startRecording {
    self.isRecording = YES;
    [self swizzleAllMethods];
}

- (void)stopRecording {
    self.isRecording = NO;
}

- (void)recordMethodCall:(SEL)selector class:(Class)cls time:(NSTimeInterval)time {
    if (!self.isRecording) return;
    
    NSString *key = [NSString stringWithFormat:@"%@[%@]", 
                     NSStringFromClass(cls), 
                     NSStringFromSelector(selector)];
    
    NSMutableDictionary *stats = self.methodCallStats[key];
    if (!stats) {
        stats = [@{
            @"count": @0,
            @"totalTime": @0.0,
            @"minTime": @(DBL_MAX),
            @"maxTime": @0.0
        } mutableCopy];
        self.methodCallStats[key] = stats;
    }
    
    stats[@"count"] = @([stats[@"count"] integerValue] + 1);
    stats[@"totalTime"] = @([stats[@"totalTime"] doubleValue] + time);
    stats[@"minTime"] = @(MIN([stats[@"minTime"] doubleValue], time));
    stats[@"maxTime"] = @(MAX([stats[@"maxTime"] doubleValue], time));
}

- (void)swizzleAllMethods {
    unsigned int classCount;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        [self swizzleMethodsInClass:cls];
    }
    
    free(classes);
}

- (void)swizzleMethodsInClass:(Class)cls {
    unsigned int methodCount;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        
        // 创建新的方法实现
        IMP originalImp = method_getImplementation(method);
        IMP newImp = imp_implementationWithBlock(^(id self, ...) {
            NSDate *start = [NSDate date];
            
            // 调用原始方法
            typedef id (*originalIMP)(id, SEL, ...);
            originalIMP imp = (originalIMP)originalImp;
            id result = imp(self, selector);
            
            NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:start];
            [[RTBMethodProfiler sharedInstance] recordMethodCall:selector 
                                                         class:cls 
                                                         time:elapsed];
            
            return result;
        });
        
        method_setImplementation(method, newImp);
    }
    
    free(methods);
}

+ (void)startProfiling {
    if (_profiling_enabled) return;
    
    // 初始化线程存储
    pthread_key_create(&_thread_key, &release_thread_call_stack);
    
    // 使用正确的函数名和结构体名称
    flex_rebind_symbols((struct flex_rebinding[1]){{"objc_msgSend", (void *)replacement_objc_msgSend, (void **)&orig_objc_msgSend}}, 1);
    
    _profiling_enabled = YES;
}

+ (void)stopProfiling {
    if (!_profiling_enabled) return;
    
    // 使用正确的函数名和结构体名称
    flex_rebind_symbols((struct flex_rebinding[1]){{"objc_msgSend", (void *)orig_objc_msgSend, NULL}}, 1);
    
    _profiling_enabled = NO;
}

- (NSDictionary *)getMethodCallStats {
    // 如果正在记录，创建一个副本以避免并发问题
    if (self.isRecording) {
        return [self.methodCallStats copy];
    }
    return self.methodCallStats;
}

+ (NSArray<NSDictionary *> *)getProfiledMethods {
    // 返回分析结果...
    NSMutableArray *results = [NSMutableArray array];
    NSDictionary *stats = [[self sharedInstance] getMethodCallStats];
    
    for (NSString *methodKey in stats) {
        NSDictionary *methodStats = stats[methodKey];
        [results addObject:@{
            @"method": methodKey,
            @"stats": methodStats
        }];
    }
    
    return results;
}

- (BOOL)swizzleMethod:(Method)method inClass:(Class)cls {
    // 这里是函数的实现代码
    
    // 确保在右花括号前添加返回语句
    return YES;
}

@end