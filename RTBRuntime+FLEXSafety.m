#import "RTBRuntime+FLEXSafety.h"
#import <malloc/malloc.h>
#import <mach/mach.h>
#import <objc/runtime.h>

// 模仿objc对象结构用于检查内存范围是否为对象
typedef struct {
    Class isa;
} rtb_maybe_object_t;

static CFMutableSetRef registeredClasses;

@implementation RTBRuntime (FLEXSafety)

+ (void)load {
    // 初始化已注册类的集合
    registeredClasses = CFSetCreateMutable(NULL, 0, NULL);
    
    // 获取所有运行时类
    int numClasses = objc_getClassList(NULL, 0);
    Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
    numClasses = objc_getClassList(classes, numClasses);
    
    for (int i = 0; i < numClasses; i++) {
        CFSetAddValue(registeredClasses, (__bridge const void *)(classes[i]));
    }
    
    free(classes);
}

- (BOOL)flex_pointerIsReadable:(const void *)ptr {
    if (!ptr) return NO;
    
    vm_size_t vmsize;
    vm_address_t address = (vm_address_t)ptr;
    vm_region_basic_info_data_t info;
    mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT;
    memory_object_name_t object;
    
    // 根据架构使用不同的 vm_region 函数
    kern_return_t error;
#ifdef __LP64__
    error = vm_region_64(
        mach_task_self(),
        &address,
        &vmsize,
        VM_REGION_BASIC_INFO,
        (vm_region_info_t)&info,
        &info_count,
        &object
    );
#else
    error = vm_region(
        mach_task_self(),
        &address,
        &vmsize,
        VM_REGION_BASIC_INFO,
        (vm_region_info_t)&info,
        &info_count,
        &object
    );
#endif
    
    if (error != KERN_SUCCESS) {
        return NO;
    }
    
    // 检查是否有读权限
    if (!(info.protection & VM_PROT_READ)) {
        return NO;
    }
    
    // 尝试读取内存
    vm_size_t size = 0;
    char buf[sizeof(uintptr_t)];
    error = vm_read_overwrite(mach_task_self(), (vm_address_t)ptr, sizeof(uintptr_t), (vm_address_t)buf, &size);
    
    return error == KERN_SUCCESS;
}

- (BOOL)flex_pointerIsValidObjcObject:(const void *)ptr {
    uintptr_t pointer = (uintptr_t)ptr;
    
    if (!ptr) return NO;
    
#if OBJC_HAVE_TAGGED_POINTERS
    // 检查标记指针
    if (pointer & 0x1) {
        return YES; // 标记指针是有效的objc对象
    }
#endif
    
    // 检查指针对齐
    if (pointer % sizeof(void *) != 0) {
        return NO;
    }
    
    // 检查是否可读
    if (![self flex_pointerIsReadable:ptr]) {
        return NO;
    }
    
    // 检查isa指针
    rtb_maybe_object_t *obj = (rtb_maybe_object_t *)ptr;
    Class isaCls = obj->isa;
    
    // 在arm64上处理isa掩码
#ifdef __arm64__
    extern uint64_t objc_debug_isa_class_mask WEAK_IMPORT_ATTRIBUTE;
    if (&objc_debug_isa_class_mask != NULL) {
        isaCls = (__bridge Class)((void *)((uint64_t)isaCls & objc_debug_isa_class_mask));
    }
#endif
    
    // 检查isa是否是已知的类
    if (CFSetContainsValue(registeredClasses, (__bridge const void *)(isaCls))) {
        return YES;
    }
    
    return NO;
}

- (NSDictionary *)flex_getBasicMemoryInfo {
    // 获取基本内存信息
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &size);
    
    if (kerr == KERN_SUCCESS) {
        return @{
            @"residentMemory": @(info.resident_size / 1024.0 / 1024.0), // MB
            @"virtualMemory": @(info.virtual_size / 1024.0 / 1024.0),   // MB
            @"suspendCount": @(info.suspend_count),
            @"timestamp": [NSDate date]
        };
    }
    
    return @{
        @"error": @"Failed to get memory info",
        @"timestamp": [NSDate date]
    };
}

// 检查是否还有其他缺失的方法，如果有也需要添加
- (NSDictionary *)flex_getHeapSnapshot {
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    
    // 获取内存使用统计
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &size);
    
    if (kerr == KERN_SUCCESS) {
        snapshot[@"residentSize"] = @(info.resident_size);
        snapshot[@"virtualSize"] = @(info.virtual_size);
    }
    
    // 获取 malloc 统计信息
    malloc_statistics_t stats;
    malloc_zone_statistics(NULL, &stats);
    
    snapshot[@"mallocStats"] = @{
        @"blocksInUse": @(stats.blocks_in_use),
        @"sizeInUse": @(stats.size_in_use),
        @"maxSizeInUse": @(stats.max_size_in_use),
        @"sizeAllocated": @(stats.size_allocated)
    };
    
    snapshot[@"timestamp"] = [NSDate date];
    
    return snapshot;
}

- (NSArray *)flex_findInstancesWithPrefix:(NSString *)prefix {
    NSMutableArray *instances = [NSMutableArray array];
    
    if (!prefix) return instances;
    
    // 获取所有类
    int numClasses = objc_getClassList(NULL, 0);
    Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
    numClasses = objc_getClassList(classes, numClasses);
    
    for (int i = 0; i < numClasses; i++) {
        Class cls = classes[i];
        NSString *className = NSStringFromClass(cls);
        
        if ([className hasPrefix:prefix]) {
            [instances addObject:@{
                @"className": className,
                @"class": cls
            }];
        }
    }
    
    free(classes);
    return instances;
}

- (NSArray *)flex_safeGetAllInstancesOfClass:(Class)cls {
    NSMutableArray *instances = [NSMutableArray array];
    
    if (!cls) return instances;
    
    // 这里可以实现更复杂的实例查找逻辑
    // 由于安全性考虑，返回空数组或基本信息
    return @[@{
        @"className": NSStringFromClass(cls),
        @"note": @"实例查找功能需要更复杂的实现"
    }];
}

- (id)flex_safeGetObjectAtAddress:(NSUInteger)address {
    const void *ptr = (const void *)address;
    
    // 首先检查指针是否可读
    if (![self flex_pointerIsReadable:ptr]) {
        return nil;
    }
    
    // 检查是否是有效的 Objective-C 对象
    if (![self flex_pointerIsValidObjcObject:ptr]) {
        return nil;
    }
    
    // 安全地转换为对象
    @try {
        id object = (__bridge id)ptr;
        return object;
    } @catch (NSException *exception) {
        return nil;
    }
}

@end

@implementation NSObject (RTBRuntimeSafety)

+ (NSArray *)flex_safePropertyList {
    NSMutableArray *properties = [NSMutableArray array];
    
    unsigned int count = 0;
    objc_property_t *propertyList = class_copyPropertyList(self, &count);
    
    for (unsigned int i = 0; i < count; i++) {
        objc_property_t property = propertyList[i];
        NSString *propertyName = @(property_getName(property));
        NSString *propertyAttributes = @(property_getAttributes(property));
        
        [properties addObject:@{
            @"name": propertyName,
            @"attributes": propertyAttributes
        }];
    }
    
    free(propertyList);
    return properties;
}

+ (NSArray *)flex_safeMethodList {
    NSMutableArray *methods = [NSMutableArray array];
    
    unsigned int count = 0;
    Method *methodList = class_copyMethodList(self, &count);
    
    for (unsigned int i = 0; i < count; i++) {
        Method method = methodList[i];
        SEL selector = method_getName(method);
        
        [methods addObject:@{
            @"name": NSStringFromSelector(selector),
            @"selector": NSStringFromSelector(selector)
        }];
    }
    
    free(methodList);
    return methods;
}

+ (NSArray *)flex_safeProtocolList {
    NSMutableArray *protocols = [NSMutableArray array];
    
    unsigned int count = 0;
    Protocol * __unsafe_unretained *protocolList = class_copyProtocolList(self, &count);
    
    for (unsigned int i = 0; i < count; i++) {
        Protocol *protocol = protocolList[i];
        NSString *protocolName = @(protocol_getName(protocol));
        
        [protocols addObject:@{
            @"name": protocolName
        }];
    }
    
    free(protocolList);
    return protocols;
}

+ (NSArray *)flex_safeIvarList {
    NSMutableArray *ivars = [NSMutableArray array];
    
    unsigned int count = 0;
    Ivar *ivarList = class_copyIvarList(self, &count);
    
    for (unsigned int i = 0; i < count; i++) {
        Ivar ivar = ivarList[i];
        NSString *ivarName = @(ivar_getName(ivar));
        NSString *ivarType = @(ivar_getTypeEncoding(ivar));
        
        [ivars addObject:@{
            @"name": ivarName,
            @"type": ivarType,
            @"offset": @(ivar_getOffset(ivar))
        }];
    }
    
    free(ivarList);
    return ivars;
}

@end