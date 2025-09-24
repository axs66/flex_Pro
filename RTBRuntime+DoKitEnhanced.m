#import "RTBRuntime+DoKitEnhanced.h"
#import <objc/runtime.h>
#import <malloc/malloc.h>
#import <dlfcn.h>
#import <mach/mach.h>

@implementation RTBRuntime (DoKitEnhanced)

- (NSArray *)dokit_getAllClassesWithPrefix:(NSString *)prefix {
    NSMutableArray *results = [NSMutableArray array];
    
    int numClasses = objc_getClassList(NULL, 0);
    Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
    numClasses = objc_getClassList(classes, numClasses);
    
    for (int i = 0; i < numClasses; i++) {
        Class cls = classes[i];
        NSString *className = NSStringFromClass(cls);
        
        if (!prefix || [className hasPrefix:prefix]) {
            NSMutableDictionary *classInfo = [NSMutableDictionary dictionary];
            classInfo[@"className"] = className;
            classInfo[@"superclass"] = NSStringFromClass(class_getSuperclass(cls));
            classInfo[@"instanceSize"] = @(class_getInstanceSize(cls));
            classInfo[@"methodCount"] = @([self dokit_getMethodCountForClass:cls]);
            classInfo[@"propertyCount"] = @([self dokit_getPropertyCountForClass:cls]);
            classInfo[@"protocolCount"] = @([self dokit_getProtocolCountForClass:cls]);
            
            [results addObject:classInfo];
        }
    }
    
    free(classes);
    return [results sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"className" ascending:YES]]];
}

- (NSArray *)dokit_getMethodsForClass:(Class)cls includeHooked:(BOOL)includeHooked {
    NSMutableArray *methods = [NSMutableArray array];
    
    // 实例方法
    unsigned int instanceMethodCount;
    Method *instanceMethods = class_copyMethodList(cls, &instanceMethodCount);
    
    for (unsigned int i = 0; i < instanceMethodCount; i++) {
        Method method = instanceMethods[i];
        SEL selector = method_getName(method);
        NSString *selectorName = NSStringFromSelector(selector);
        
        NSMutableDictionary *methodInfo = [NSMutableDictionary dictionary];
        methodInfo[@"selector"] = selectorName;
        methodInfo[@"type"] = @"instance";
        methodInfo[@"typeEncoding"] = [NSString stringWithUTF8String:method_getTypeEncoding(method)];
        
        // 检查是否被Hook（基于DoKit的Hook检测逻辑）
        IMP implementation = method_getImplementation(method);
        methodInfo[@"implementation"] = [NSString stringWithFormat:@"%p", implementation];
        methodInfo[@"isHooked"] = @([self dokit_isMethodHooked:method]);
        
        if (!includeHooked && [methodInfo[@"isHooked"] boolValue]) {
            continue;
        }
        
        [methods addObject:methodInfo];
    }
    
    free(instanceMethods);
    
    // 类方法
    unsigned int classMethodCount;
    Method *classMethods = class_copyMethodList(object_getClass(cls), &classMethodCount);
    
    for (unsigned int i = 0; i < classMethodCount; i++) {
        Method method = classMethods[i];
        SEL selector = method_getName(method);
        NSString *selectorName = NSStringFromSelector(selector);
        
        NSMutableDictionary *methodInfo = [NSMutableDictionary dictionary];
        methodInfo[@"selector"] = selectorName;
        methodInfo[@"type"] = @"class";
        methodInfo[@"typeEncoding"] = [NSString stringWithUTF8String:method_getTypeEncoding(method)];
        
        IMP implementation = method_getImplementation(method);
        methodInfo[@"implementation"] = [NSString stringWithFormat:@"%p", implementation];
        methodInfo[@"isHooked"] = @([self dokit_isMethodHooked:method]);
        
        if (!includeHooked && [methodInfo[@"isHooked"] boolValue]) {
            continue;
        }
        
        [methods addObject:methodInfo];
    }
    
    free(classMethods);
    
    return methods;
}

- (NSArray *)dokit_getHookedMethodsForClass:(Class)cls {
    return [self dokit_getMethodsForClass:cls includeHooked:NO];
}

- (BOOL)dokit_isMethodHooked:(Method)method {
    // 基于DoKit的Hook检测逻辑
    // 检查方法实现是否指向了Hook函数
    IMP implementation = method_getImplementation(method);
    Dl_info info;
    if (dladdr((void *)implementation, &info)) {
        NSString *imageName = [NSString stringWithUTF8String:info.dli_fname];
        // 如果实现在主程序或已知的Hook库中，可能被Hook了
        if ([imageName containsString:@"DYYY"] || 
            [imageName containsString:@"DoraemonKit"] ||
            [imageName containsString:@"substitute"] ||
            [imageName containsString:@"fishhook"]) {
            return YES;
        }
    }
    return NO;
}

- (NSDictionary *)dokit_getClassHierarchyTree {
    NSMutableDictionary *hierarchyTree = [NSMutableDictionary dictionary];
    
    int numClasses = objc_getClassList(NULL, 0);
    Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
    numClasses = objc_getClassList(classes, numClasses);
    
    // 构建类层次树
    for (int i = 0; i < numClasses; i++) {
        Class cls = classes[i];
        NSString *className = NSStringFromClass(cls);
        Class superClass = class_getSuperclass(cls);
        
        if (superClass) {
            NSString *superClassName = NSStringFromClass(superClass);
            NSMutableArray *subclasses = hierarchyTree[superClassName];
            if (!subclasses) {
                subclasses = [NSMutableArray array];
                hierarchyTree[superClassName] = subclasses;
            }
            [subclasses addObject:className];
        } else {
            // 根类
            if (!hierarchyTree[className]) {
                hierarchyTree[className] = [NSMutableArray array];
            }
        }
    }
    
    free(classes);
    return hierarchyTree;
}

- (NSArray *)dokit_getAllInstancesOfClass:(Class)cls {
    NSMutableArray *instances = [NSMutableArray array];
    
    // 使用DoKit的内存扫描技术
    vm_address_t *zones = NULL;
    unsigned int zoneCount = 0;
    
    kern_return_t result = malloc_get_all_zones(mach_task_self(), NULL, &zones, &zoneCount);
    if (result == KERN_SUCCESS) {
        for (unsigned int i = 0; i < zoneCount; i++) {
            malloc_zone_t *zone = (malloc_zone_t *)zones[i];
            if (zone && zone->introspect && zone->introspect->enumerator) {
                zone->introspect->enumerator(mach_task_self(), 
                                       (__bridge void *)cls, 
                                       MALLOC_PTR_IN_USE_RANGE_TYPE, 
                                       (vm_address_t)zone, 
                                       NULL, 
                                       dokit_enumerator_callback);
            }
        }
    }
    
    return instances;
}

// 内存枚举回调函数
static void dokit_enumerator_callback(task_t task, void *context, unsigned type, vm_range_t *ranges, unsigned count) {
    Class targetClass = (__bridge Class)context;
    
    for (unsigned i = 0; i < count; i++) {
        vm_range_t range = ranges[i];
        void *ptr = (void *)range.address;
        
        // 检查是否是目标类的实例
        if (ptr && object_getClass((__bridge id)ptr) == targetClass) {
            // 找到实例
        }
    }
}

- (NSUInteger)dokit_getMethodCountForClass:(Class)cls {
    unsigned int count;
    Method *methods = class_copyMethodList(cls, &count);
    free(methods);
    return count;
}

- (NSUInteger)dokit_getPropertyCountForClass:(Class)cls {
    unsigned int count;
    objc_property_t *properties = class_copyPropertyList(cls, &count);
    free(properties);
    return count;
}

- (NSUInteger)dokit_getProtocolCountForClass:(Class)cls {
    unsigned int count;
    Protocol * __unsafe_unretained *protocols = class_copyProtocolList(cls, &count);
    free(protocols);
    return count;
}

- (NSArray *)dokit_searchClassesByKeyword:(NSString *)keyword {
    // 实现搜索功能
    NSMutableArray *results = [NSMutableArray array];
    // 实现代码...
    return results;
}

- (NSUInteger)dokit_getInstanceCountForClass:(Class)cls {
    // 实现计数功能
    return 0; // 临时返回值，待实现
}

- (NSArray *)dokit_getViewHierarchyFromView:(UIView *)view {
    // 实现视图层次功能
    NSMutableArray *hierarchy = [NSMutableArray array];
    // 实现代码...
    return hierarchy;
}

- (NSArray *)dokit_getAllNetworkRequests {
    // 实现获取网络请求功能
    return @[];
}

- (void)dokit_startNetworkMonitoring {
    // 实现开始监控网络
}

- (void)dokit_stopNetworkMonitoring {
    // 实现停止监控网络
}

@end