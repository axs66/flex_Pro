#import "FLEXRuntimeClient+RuntimeBrowser.h"
#import "FLEXRuntimeUtility.h"
#import <objc/runtime.h>
#import <mach/mach.h>
#import <malloc/malloc.h>

// 添加缺失的结构体定义
typedef struct {
    Class targetClass;
    NSMutableArray *instances;
    NSUInteger maxInstances;
} RuntimeBrowserEnumerationContext;

// 修改函数指针声明，确保类型正确
static void flex_enumerateInstances(task_t task, void *context, unsigned type_mask, vm_address_t zone_address, memory_reader_t reader, vm_range_recorder_t recorder);

@implementation FLEXRuntimeClient (RuntimeBrowser)

- (NSArray *)getAllInstancesOfClass:(Class)cls {
    NSMutableArray *instances = [NSMutableArray array];
    
    if (!cls) {
        return instances;
    }
    
    // 使用 malloc_zone_t 遍历堆内存
    vm_address_t *zones = NULL;
    unsigned int zoneCount = 0;
    
    kern_return_t result = malloc_get_all_zones(0, NULL, &zones, &zoneCount);
    if (result != KERN_SUCCESS) {
        return instances;
    }
    
    for (unsigned int i = 0; i < zoneCount; i++) {
        malloc_zone_t *zone = (malloc_zone_t *)zones[i];
        if (!zone || !zone->introspect || !zone->introspect->enumerator) {
            continue;
        }
        
        // 创建枚举上下文
        RuntimeBrowserEnumerationContext context = {
            .targetClass = cls,
            .instances = instances,
            .maxInstances = 1000 // 限制最大实例数以避免内存问题
        };
        
        zone->introspect->enumerator(mach_task_self(), &context, MALLOC_PTR_IN_USE_RANGE_TYPE, 
                                   zones[i], NULL, enumerateInstancesCallback);
    }
    
    return [instances copy];
}

// 内存枚举回调函数
static void enumerateInstancesCallback(task_t task, void *context, unsigned type, 
                                     vm_range_t *ranges, unsigned count) {
    RuntimeBrowserEnumerationContext *enumContext = (RuntimeBrowserEnumerationContext *)context;
    
    for (unsigned i = 0; i < count; i++) {
        vm_range_t range = ranges[i];
        
        // 检查地址范围是否有效
        if (range.size < sizeof(void *)) {
            continue;
        }
        
        // 尝试读取对象指针
        void *ptr = (void *)range.address;
        
        @try {
            // 验证是否为有效的Objective-C对象
            if ([FLEXRuntimeUtility pointerIsValidObjcObject:ptr]) {
                id obj = (__bridge id)ptr;
                
                // 检查类是否匹配
                if ([obj isKindOfClass:enumContext->targetClass]) {
                    [enumContext->instances addObject:obj];
                    
                    // 限制实例数量以避免内存问题
                    if (enumContext->instances.count >= enumContext->maxInstances) {
                        return;
                    }
                }
            }
        } @catch (NSException *exception) {
            // 忽略无效对象访问异常
            continue;
        }
    }
}

- (NSUInteger)getInstanceCountForClass:(Class)cls {
    if (!cls) {
        return 0;
    }
    
    // 对于性能考虑，使用估算方法
    NSArray *instances = [self getAllInstancesOfClass:cls];
    return instances.count;
}

- (NSArray<Class> *)getClassHierarchy:(Class)cls {
    NSMutableArray *hierarchy = [NSMutableArray array];
    
    Class currentClass = cls;
    while (currentClass) {
        [hierarchy addObject:currentClass];
        currentClass = class_getSuperclass(currentClass);
    }
    
    return [hierarchy copy];
}

- (NSArray<Class> *)getSubclasses:(Class)cls {
    NSMutableArray *subclasses = [NSMutableArray array];
    
    if (!cls) {
        return subclasses;
    }
    
    unsigned int classCount = 0;
    Class *allClasses = objc_copyClassList(&classCount);
    
    if (!allClasses) {
        return subclasses;
    }
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class candidateClass = allClasses[i];
        Class superclass = class_getSuperclass(candidateClass);
        
        // 检查是否为直接子类
        if (superclass == cls) {
            [subclasses addObject:candidateClass];
        }
    }
    
    free(allClasses);
    
    // 按类名排序
    [subclasses sortUsingComparator:^NSComparisonResult(Class class1, Class class2) {
        NSString *name1 = NSStringFromClass(class1);
        NSString *name2 = NSStringFromClass(class2);
        return [name1 compare:name2];
    }];
    
    return [subclasses copy];
}

- (NSDictionary *)getClassStatistics:(Class)cls {
    NSMutableDictionary *statistics = [NSMutableDictionary dictionary];
    
    if (!cls) {
        return statistics;
    }
    
    // 基本信息
    statistics[@"className"] = NSStringFromClass(cls);
    statistics[@"superclass"] = class_getSuperclass(cls) ? NSStringFromClass(class_getSuperclass(cls)) : @"(root)";
    statistics[@"instanceSize"] = @(class_getInstanceSize(cls));
    
    // 方法统计
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    statistics[@"instanceMethodCount"] = @(methodCount);
    if (methods) free(methods);
    
    unsigned int classMethodCount = 0;
    Method *classMethods = class_copyMethodList(object_getClass(cls), &classMethodCount);
    statistics[@"classMethodCount"] = @(classMethodCount);
    if (classMethods) free(classMethods);
    
    // 属性统计
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    statistics[@"propertyCount"] = @(propertyCount);
    if (properties) free(properties);
    
    // 实例变量统计
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    statistics[@"ivarCount"] = @(ivarCount);
    if (ivars) free(ivars);
    
    // 协议统计
    unsigned int protocolCount = 0;
    Protocol * __unsafe_unretained *protocols = class_copyProtocolList(cls, &protocolCount);
    statistics[@"protocolCount"] = @(protocolCount);
    if (protocols) free(protocols);
    
    // 子类统计
    NSArray *subclasses = [self getSubclasses:cls];
    statistics[@"subclassCount"] = @(subclasses.count);
    
    // 实例统计（可能耗时）
    NSUInteger instanceCount = [self getInstanceCountForClass:cls];
    statistics[@"instanceCount"] = @(instanceCount);
    
    return [statistics copy];
}

- (NSArray<NSDictionary *> *)getMethodsForClass:(Class)cls includeInherited:(BOOL)includeInherited {
    NSMutableArray *methodsInfo = [NSMutableArray array];
    
    if (!cls) {
        return methodsInfo;
    }
    
    // 实例方法
    [self addMethodsFromClass:cls 
                   isInstance:YES 
                 toMethodsInfo:methodsInfo 
              includeInherited:includeInherited];
    
    // 类方法
    [self addMethodsFromClass:object_getClass(cls) 
                   isInstance:NO 
                 toMethodsInfo:methodsInfo 
              includeInherited:includeInherited];
    
    // 按方法名排序
    [methodsInfo sortUsingComparator:^NSComparisonResult(NSDictionary *method1, NSDictionary *method2) {
        NSString *name1 = method1[@"name"];
        NSString *name2 = method2[@"name"];
        return [name1 compare:name2];
    }];
    
    return [methodsInfo copy];
}

- (void)addMethodsFromClass:(Class)cls 
                 isInstance:(BOOL)isInstance 
               toMethodsInfo:(NSMutableArray *)methodsInfo 
            includeInherited:(BOOL)includeInherited {
    
    Class currentClass = cls;
    
    do {
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(currentClass, &methodCount);
        
        if (methods) {
            for (unsigned int i = 0; i < methodCount; i++) {
                Method method = methods[i];
                SEL selector = method_getName(method);
                IMP implementation = method_getImplementation(method);
                const char *typeEncoding = method_getTypeEncoding(method);
                
                NSMutableDictionary *methodInfo = [NSMutableDictionary dictionary];
                methodInfo[@"name"] = NSStringFromSelector(selector);
                methodInfo[@"isInstance"] = @(isInstance);
                methodInfo[@"implementation"] = [NSString stringWithFormat:@"%p", implementation];
                methodInfo[@"typeEncoding"] = typeEncoding ? @(typeEncoding) : @"";
                methodInfo[@"declaringClass"] = NSStringFromClass(currentClass);
                
                // 解析方法签名
                NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:typeEncoding ?: "v@:"];
                if (signature) {
                    methodInfo[@"returnType"] = @(signature.methodReturnType);
                    methodInfo[@"argumentCount"] = @(signature.numberOfArguments);
                    
                    NSMutableArray *argumentTypes = [NSMutableArray array];
                    for (NSUInteger j = 0; j < signature.numberOfArguments; j++) {
                        const char *argType = [signature getArgumentTypeAtIndex:j];
                        [argumentTypes addObject:@(argType)];
                    }
                    methodInfo[@"argumentTypes"] = argumentTypes;
                }
                
                [methodsInfo addObject:methodInfo];
            }
            
            free(methods);
        }
        
        currentClass = class_getSuperclass(currentClass);
    } while (includeInherited && currentClass);
}

- (NSArray<NSDictionary *> *)getPropertiesForClass:(Class)cls includeInherited:(BOOL)includeInherited {
    NSMutableArray *propertiesInfo = [NSMutableArray array];
    
    if (!cls) {
        return propertiesInfo;
    }
    
    Class currentClass = cls;
    
    do {
        unsigned int propertyCount = 0;
        objc_property_t *properties = class_copyPropertyList(currentClass, &propertyCount);
        
        if (properties) {
            for (unsigned int i = 0; i < propertyCount; i++) {
                objc_property_t property = properties[i];
                const char *name = property_getName(property);
                const char *attributes = property_getAttributes(property);
                
                NSMutableDictionary *propertyInfo = [NSMutableDictionary dictionary];
                propertyInfo[@"name"] = @(name);
                propertyInfo[@"attributes"] = attributes ? @(attributes) : @"";
                propertyInfo[@"declaringClass"] = NSStringFromClass(currentClass);
                
                // 解析属性特性
                NSDictionary *parsedAttributes = [self parsePropertyAttributes:@(attributes)];
                [propertyInfo addEntriesFromDictionary:parsedAttributes];
                
                [propertiesInfo addObject:propertyInfo];
            }
            
            free(properties);
        }
        
        currentClass = class_getSuperclass(currentClass);
    } while (includeInherited && currentClass);
    
    // 按属性名排序
    [propertiesInfo sortUsingComparator:^NSComparisonResult(NSDictionary *prop1, NSDictionary *prop2) {
        NSString *name1 = prop1[@"name"];
        NSString *name2 = prop2[@"name"];
        return [name1 compare:name2];
    }];
    
    return [propertiesInfo copy];
}

- (NSDictionary *)parsePropertyAttributes:(NSString *)attributes {
    NSMutableDictionary *parsed = [NSMutableDictionary dictionary];
    
    if (!attributes || attributes.length == 0) {
        return parsed;
    }
    
    NSArray *components = [attributes componentsSeparatedByString:@","];
    
    for (NSString *component in components) {
        if (component.length == 0) continue;
        
        unichar firstChar = [component characterAtIndex:0];
        
        switch (firstChar) {
            case 'T': // 类型
                if (component.length > 1) {
                    parsed[@"type"] = [component substringFromIndex:1];
                }
                break;
            case 'R': // readonly
                parsed[@"readonly"] = @YES;
                break;
            case 'C': // copy
                parsed[@"copy"] = @YES;
                break;
            case '&': // retain/strong
                parsed[@"strong"] = @YES;
                break;
            case 'W': // weak
                parsed[@"weak"] = @YES;
                break;
            case 'N': // nonatomic
                parsed[@"nonatomic"] = @YES;
                break;
            case 'G': // custom getter
                if (component.length > 1) {
                    parsed[@"getter"] = [component substringFromIndex:1];
                }
                break;
            case 'S': // custom setter
                if (component.length > 1) {
                    parsed[@"setter"] = [component substringFromIndex:1];
                }
                break;
            case 'V': // instance variable name
                if (component.length > 1) {
                    parsed[@"ivarName"] = [component substringFromIndex:1];
                }
                break;
        }
    }
    
    return parsed;
}

- (NSArray<NSDictionary *> *)getIvarsForClass:(Class)cls includeInherited:(BOOL)includeInherited {
    NSMutableArray *ivarsInfo = [NSMutableArray array];
    
    if (!cls) {
        return ivarsInfo;
    }
    
    Class currentClass = cls;
    
    do {
        unsigned int ivarCount = 0;
        Ivar *ivars = class_copyIvarList(currentClass, &ivarCount);
        
        if (ivars) {
            for (unsigned int i = 0; i < ivarCount; i++) {
                Ivar ivar = ivars[i];
                const char *name = ivar_getName(ivar);
                const char *typeEncoding = ivar_getTypeEncoding(ivar);
                ptrdiff_t offset = ivar_getOffset(ivar);
                
                NSMutableDictionary *ivarInfo = [NSMutableDictionary dictionary];
                ivarInfo[@"name"] = name ? @(name) : @"";
                ivarInfo[@"typeEncoding"] = typeEncoding ? @(typeEncoding) : @"";
                ivarInfo[@"offset"] = @(offset);
                ivarInfo[@"declaringClass"] = NSStringFromClass(currentClass);
                
                // 尝试获取当前值（仅对实例变量有效）
                @try {
                    // 这里需要实例对象才能获取值，暂时跳过
                    ivarInfo[@"value"] = @"(需要实例对象)";
                } @catch (NSException *exception) {
                    ivarInfo[@"value"] = @"(无法访问)";
                }
                
                [ivarsInfo addObject:ivarInfo];
            }
            
            free(ivars);
        }
        
        currentClass = class_getSuperclass(currentClass);
    } while (includeInherited && currentClass);
    
    // 按名称排序
    [ivarsInfo sortUsingComparator:^NSComparisonResult(NSDictionary *ivar1, NSDictionary *ivar2) {
        NSString *name1 = ivar1[@"name"];
        NSString *name2 = ivar2[@"name"];
        return [name1 compare:name2];
    }];
    
    return [ivarsInfo copy];
}

// 为缺失的方法添加实现
- (NSDictionary *)getDetailedClassInfo:(Class)cls {
    if (!cls) return nil;
    
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"name"] = NSStringFromClass(cls);
    info[@"superclass"] = NSStringFromClass(class_getSuperclass(cls));
    info[@"instanceSize"] = @(class_getInstanceSize(cls));
    
    // 统计属性、方法和实例数量
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    free(properties);
    info[@"propertyCount"] = @(propertyCount);
    
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    free(methods);
    info[@"methodCount"] = @(methodCount);
    
    // 获取实例数量，使用已实现的 getAllInstancesOfClass 方法
    NSArray *instances = [self getAllInstancesOfClass:cls];
    info[@"instanceCount"] = @(instances.count);
    
    return info;
}

- (NSArray *)subclassesOfClass:(NSString *)className {
    if (!className) return @[];
    
    Class parentClass = NSClassFromString(className);
    if (!parentClass) return @[];
    
    NSMutableArray *subclasses = [NSMutableArray array];
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        Class superclass = class_getSuperclass(cls);
        
        while (superclass && superclass != parentClass) {
            superclass = class_getSuperclass(superclass);
        }
        
        if (superclass == parentClass) {
            [subclasses addObject:cls];
        }
    }
    
    free(classes);
    return subclasses;
}

- (NSString *)generateHeaderForClass:(Class)cls {
    if (!cls) return @"";
    
    NSMutableString *header = [NSMutableString string];
    
    // 生成基本类信息
    [header appendFormat:@"@interface %@ : %@\n\n", NSStringFromClass(cls), NSStringFromClass(class_getSuperclass(cls))];
    
    // 生成属性定义
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    
    for (unsigned int i = 0; i < propertyCount; i++) {
        objc_property_t property = properties[i];
        const char *name = property_getName(property);
        const char *attrs = property_getAttributes(property);
        [header appendFormat:@"@property %s; // %s\n", name, attrs];
    }
    free(properties);
    
    [header appendString:@"\n"];
    
    // 生成方法定义
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        const char *types = method_getTypeEncoding(method);
        [header appendFormat:@"- %s %s; // %s\n", 
                 types ? types : "void", 
                 sel_getName(selector),
                 types ? types : "unknown"];
    }
    free(methods);
    
    [header appendString:@"\n@end"];
    
    return header;
}

// 修复 flex_enumerateInstances 实现
static void __attribute__((unused)) flex_enumerateInstances(task_t task, void *context, unsigned type_mask, vm_address_t zone_address, memory_reader_t reader, vm_range_recorder_t recorder) {
    RuntimeBrowserEnumerationContext *enumContext = (RuntimeBrowserEnumerationContext *)context;
    
    // 遍历内存中的各个对象
    for (vm_address_t ptr = zone_address; ptr < zone_address + 1000 * sizeof(id); ptr += sizeof(id)) {
        @try {
            // 验证是否为有效的Objective-C对象
            if ([FLEXRuntimeUtility pointerIsValidObjcObject:(const void *)ptr]) {
                id obj = (__bridge id)((void *)ptr);
                
                // 检查类是否匹配
                if ([obj isKindOfClass:enumContext->targetClass]) {
                    [enumContext->instances addObject:obj];
                    
                    // 限制实例数量以避免内存问题
                    if (enumContext->instances.count >= enumContext->maxInstances) {
                        return;
                    }
                }
            }
        } @catch (NSException *exception) {
            // 忽略无效对象访问异常
        }
    }
}

@end