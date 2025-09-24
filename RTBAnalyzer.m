#import "RTBAnalyzer.h"
#import "RTBHierarchyManager.h"
#import <objc/runtime.h>

@implementation RTBAnalyzerResult
@end

@interface RTBAnalyzer ()
@property (nonatomic, strong) NSCache *resultCache;
@end

@implementation RTBAnalyzer

+ (instancetype)sharedAnalyzer {
    static RTBAnalyzer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _resultCache = [[NSCache alloc] init];
        _resultCache.countLimit = 200;
    }
    return self;
}

- (RTBAnalyzerResult *)analyzeClass:(Class)cls {
    NSString *className = NSStringFromClass(cls);
    RTBAnalyzerResult *cachedResult = [self.resultCache objectForKey:className];
    if (cachedResult) {
        return cachedResult;
    }
    
    RTBAnalyzerResult *result = [[RTBAnalyzerResult alloc] init];
    result.className = className;
    
    // 获取实例方法
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    result.instanceMethodCount = methodCount;
    result.methodCount += methodCount;
    free(methods);
    
    // 获取类方法
    methodCount = 0;
    methods = class_copyMethodList(object_getClass(cls), &methodCount);
    result.classMethodCount = methodCount;
    result.methodCount += methodCount;
    free(methods);
    
    // 获取属性
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    result.propertyCount = propertyCount;
    free(properties);
    
    // 获取实例变量
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    result.ivarCount = ivarCount;
    free(ivars);
    
    // 获取协议
    unsigned int protocolCount = 0;
    Protocol * __unsafe_unretained *protocols = class_copyProtocolList(cls, &protocolCount);
    result.protocolCount = protocolCount;
    free(protocols);
    
    // 实例大小
    result.instanceSize = class_getInstanceSize(cls);
    
    [self.resultCache setObject:result forKey:className];
    return result;
}

- (NSArray<RTBAnalyzerResult *> *)analyzeClassesWithPrefix:(NSString *)prefix {
    NSMutableArray<RTBAnalyzerResult *> *results = [NSMutableArray array];
    
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        NSString *className = NSStringFromClass(classes[i]);
        if ([className hasPrefix:prefix]) {
            [results addObject:[self analyzeClass:classes[i]]];
        }
    }
    
    free(classes);
    return [results copy];
}

- (NSDictionary<NSString*, NSNumber*> *)classCountByFramework {
    NSDictionary *classGroups = [[RTBHierarchyManager sharedInstance] classesGroupedByFramework];
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    [classGroups enumerateKeysAndObjectsUsingBlock:^(NSString *framework, NSArray *classes, BOOL *stop) {
        result[framework] = @(classes.count);
    }];
    
    return result;
}

- (NSDictionary<NSString*, NSNumber*> *)methodCountByFramework {
    NSDictionary *classGroups = [[RTBHierarchyManager sharedInstance] classesGroupedByFramework];
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    [classGroups enumerateKeysAndObjectsUsingBlock:^(NSString *framework, NSArray *classes, BOOL *stop) {
        NSInteger methodCount = 0;
        
        for (Class cls in classes) {
            RTBAnalyzerResult *analysis = [self analyzeClass:cls];
            methodCount += analysis.methodCount;
        }
        
        result[framework] = @(methodCount);
    }];
    
    return result;
}

- (NSDictionary<NSNumber*, NSNumber*> *)methodCountByCategory:(Class)cls {
    NSMutableDictionary<NSNumber*, NSNumber*> *result = [NSMutableDictionary dictionary];
    
    // 初始化所有类别的计数为0
    for (int i = RTBMethodCategoryLifecycle; i <= RTBMethodCategoryCustom; i++) {
        result[@(i)] = @0;
    }
    
    // 获取实例方法
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        RTBMethodInfo *info = [RTBMethodInfo methodInfoWithMethod:methods[i] 
                                                          isClass:NO 
                                                   declaringClass:cls];
        
        NSNumber *category = @(info.category);
        NSNumber *currentCount = result[category];
        result[category] = @(currentCount.integerValue + 1);
    }
    
    free(methods);
    
    // 获取类方法
    methodCount = 0;
    methods = class_copyMethodList(object_getClass(cls), &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        RTBMethodInfo *info = [RTBMethodInfo methodInfoWithMethod:methods[i] 
                                                          isClass:YES 
                                                   declaringClass:cls];
        
        NSNumber *category = @(info.category);
        NSNumber *currentCount = result[category];
        result[category] = @(currentCount.integerValue + 1);
    }
    
    free(methods);
    
    return result;
}

- (NSArray<RTBMethodInfo *> *)overriddenMethodsInClass:(Class)cls {
    NSMutableArray<RTBMethodInfo *> *overriddenMethods = [NSMutableArray array];
    Class superCls = class_getSuperclass(cls);
    
    if (!superCls) {
        return @[];
    }
    
    // 获取实例方法
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL selector = method_getName(methods[i]);
        Method superMethod = class_getInstanceMethod(superCls, selector);
        
        if (superMethod) {
            RTBMethodInfo *info = [RTBMethodInfo methodInfoWithMethod:methods[i] 
                                                              isClass:NO 
                                                       declaringClass:cls];
            [overriddenMethods addObject:info];
        }
    }
    
    free(methods);
    
    // 获取类方法
    methodCount = 0;
    methods = class_copyMethodList(object_getClass(cls), &methodCount);
    Class metaSuperCls = object_getClass(superCls);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL selector = method_getName(methods[i]);
        Method superMethod = class_getClassMethod(metaSuperCls, selector);
        
        if (superMethod) {
            RTBMethodInfo *info = [RTBMethodInfo methodInfoWithMethod:methods[i] 
                                                              isClass:YES 
                                                       declaringClass:cls];
            [overriddenMethods addObject:info];
        }
    }
    
    free(methods);
    
    return overriddenMethods;
}

- (NSArray<RTBMethodInfo *> *)methodsAddedByClass:(Class)cls {
    NSMutableArray<RTBMethodInfo *> *addedMethods = [NSMutableArray array];
    Class superCls = class_getSuperclass(cls);
    
    if (!superCls) {
        return @[];
    }
    
    // 获取实例方法
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL selector = method_getName(methods[i]);
        Method superMethod = class_getInstanceMethod(superCls, selector);
        
        if (!superMethod) {
            RTBMethodInfo *info = [RTBMethodInfo methodInfoWithMethod:methods[i] 
                                                              isClass:NO 
                                                       declaringClass:cls];
            [addedMethods addObject:info];
        }
    }
    
    free(methods);
    
    // 获取类方法
    methodCount = 0;
    methods = class_copyMethodList(object_getClass(cls), &methodCount);
    Class metaSuperCls = object_getClass(superCls);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL selector = method_getName(methods[i]);
        Method superMethod = class_getClassMethod(metaSuperCls, selector);
        
        if (!superMethod) {
            RTBMethodInfo *info = [RTBMethodInfo methodInfoWithMethod:methods[i] 
                                                              isClass:YES 
                                                       declaringClass:cls];
            [addedMethods addObject:info];
        }
    }
    
    free(methods);
    
    return addedMethods;
}

@end