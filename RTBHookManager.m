#import "RTBHookManager.h"
#import "NSObject+Doraemon.h"

@interface RTBHookManager ()
@property (nonatomic, strong) NSMutableDictionary *hookedMethods;
@property (nonatomic, strong) NSMutableArray *methodCallRecords;
@property (nonatomic, assign) BOOL isMonitoring;
@end

@implementation RTBHookManager

+ (instancetype)sharedInstance {
    static RTBHookManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RTBHookManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _hookedMethods = [NSMutableDictionary dictionary];
        _methodCallRecords = [NSMutableArray array];
        _isMonitoring = NO;
    }
    return self;
}

- (BOOL)hookClass:(Class)targetClass selector:(SEL)originalSEL withBlockImps:(id)block {
    if (!targetClass || !originalSEL || !block) {
        return NO;
    }
    
    @try {
        NSString *classKey = NSStringFromClass(targetClass);
        NSString *selectorKey = NSStringFromSelector(originalSEL);
        NSString *methodKey = [NSString stringWithFormat:@"%@_%@", classKey, selectorKey];
        
        // 检查是否已经Hook过
        if (self.hookedMethods[methodKey]) {
            return NO;
        }
        
        // 使用DoKit的swizzle方法
        SEL swizzledSEL = NSSelectorFromString([NSString stringWithFormat:@"rtb_hooked_%@", selectorKey]);
        
        // 添加新方法
        IMP blockIMP = imp_implementationWithBlock(block);
        class_addMethod(targetClass, swizzledSEL, blockIMP, method_getTypeEncoding(class_getInstanceMethod(targetClass, originalSEL)));
        
        // 交换实现
        [targetClass doraemon_swizzleInstanceMethodWithOriginSel:originalSEL swizzledSel:swizzledSEL];
        
        // 记录Hook信息
        self.hookedMethods[methodKey] = @{
            @"class": classKey,
            @"selector": selectorKey,
            @"originalSEL": NSStringFromSelector(originalSEL),
            @"swizzledSEL": NSStringFromSelector(swizzledSEL),
            @"hookTime": @([[NSDate date] timeIntervalSince1970])
        };
        
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"RTBHookManager: Hook失败 - %@", exception.reason);
        return NO;
    }
}

- (void)startMethodCallMonitoring {
    if (self.isMonitoring) return;
    
    self.isMonitoring = YES;
    [self.methodCallRecords removeAllObjects];
    
    // 实现类似DoKit的方法调用监控
    // 这里可以使用DoKit的TimeProfiler技术
}

// 添加缺失的方法实现
- (void)stopMethodCallMonitoring {
    if (!self.isMonitoring) return;
    
    self.isMonitoring = NO;
    NSLog(@"RTBHookManager: 方法调用监控已停止");
}

- (NSArray *)getAllHookedMethods {
    NSMutableArray *allHookedMethods = [NSMutableArray array];
    
    for (NSString *methodKey in self.hookedMethods) {
        [allHookedMethods addObject:self.hookedMethods[methodKey]];
    }
    
    return allHookedMethods;
}

- (BOOL)unhookClass:(Class)targetClass selector:(SEL)originalSEL {
    if (!targetClass || !originalSEL) {
        return NO;
    }
    
    @try {
        NSString *classKey = NSStringFromClass(targetClass);
        NSString *selectorKey = NSStringFromSelector(originalSEL);
        NSString *methodKey = [NSString stringWithFormat:@"%@_%@", classKey, selectorKey];
        
        // 检查是否已经Hook过
        if (!self.hookedMethods[methodKey]) {
            return NO;
        }
        
        // 恢复方法交换
        SEL swizzledSEL = NSSelectorFromString([NSString stringWithFormat:@"rtb_hooked_%@", selectorKey]);
        [targetClass doraemon_swizzleInstanceMethodWithOriginSel:originalSEL swizzledSel:swizzledSEL];
        
        // 移除Hook记录
        [self.hookedMethods removeObjectForKey:methodKey];
        
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"RTBHookManager: Unhook失败 - %@", exception.reason);
        return NO;
    }
}

@end