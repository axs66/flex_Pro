#import "RTBObjectMemoryAnalyzer.h"
#import <objc/runtime.h>
#import <malloc/malloc.h>

@implementation RTBObjectMemoryAnalyzer

+ (NSDictionary *)analyzeObjectMemoryLayout:(id)object {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    if (!object) {
        return @{@"error": @"Object is nil"};
    }
    
    // 获取对象的类
    Class cls = object_getClass(object);
    result[@"class"] = NSStringFromClass(cls);
    
    // 获取实例大小
    size_t instanceSize = class_getInstanceSize(cls);
    result[@"instanceSize"] = @(instanceSize);
    
    // 实际内存分配大小
    size_t mallocSize = malloc_size((__bridge const void *)object);
    result[@"mallocSize"] = @(mallocSize);
    
    // 内存地址
    result[@"address"] = [NSString stringWithFormat:@"%p", object];
    
    // 获取Ivars及其内存偏移和值
    NSMutableArray *ivarsArray = [NSMutableArray array];
    Class currentClass = cls;
    
    while (currentClass) {
        unsigned int ivarCount;
        Ivar *ivars = class_copyIvarList(currentClass, &ivarCount);
        
        for (unsigned int i = 0; i < ivarCount; i++) {
            Ivar ivar = ivars[i];
            NSString *ivarName = @(ivar_getName(ivar));
            NSString *ivarType = @(ivar_getTypeEncoding(ivar));
            ptrdiff_t offset = ivar_getOffset(ivar);
            
            id value = nil;
            @try {
                // 只有实例变量是对象时，才尝试获取值
                if ([ivarType hasPrefix:@"@"]) {
                    value = object_getIvar(object, ivar);
                }
            } @catch (NSException *exception) {
                value = @"<Unable to access>";
            }
            
            NSMutableDictionary *ivarInfo = [NSMutableDictionary dictionary];
            ivarInfo[@"name"] = ivarName;
            ivarInfo[@"type"] = ivarType;
            ivarInfo[@"offset"] = @(offset);
            
            if (value) {
                if ([value isKindOfClass:[NSString class]] ||
                    [value isKindOfClass:[NSNumber class]] ||
                    [value isKindOfClass:[NSDate class]]) {
                    ivarInfo[@"value"] = value;
                } else {
                    ivarInfo[@"value"] = [NSString stringWithFormat:@"%@ (%p)", [value class], value];
                }
            } else {
                ivarInfo[@"value"] = @"nil";
            }
            
            [ivarsArray addObject:ivarInfo];
        }
        
        free(ivars);
        currentClass = class_getSuperclass(currentClass);
    }
    
    result[@"ivars"] = ivarsArray;
    
    return result;
}

+ (NSUInteger)getObjectMemorySize:(id)object {
    if (!object) {
        return 0;
    }
    
    return malloc_size((__bridge const void *)object);
}

+ (NSDictionary *)getObjectReferences:(id)object {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSMutableArray *strongReferences = [NSMutableArray array];
    NSMutableArray *weakReferences = [NSMutableArray array]; // 注意：无法真正检测弱引用
    
    if (!object) {
        return @{@"error": @"Object is nil"};
    }
    
    // 获取对象的类
    Class cls = object_getClass(object);
    
    // 遍历所有实例变量，寻找对象引用
    Class currentClass = cls;
    while (currentClass) {
        unsigned int ivarCount;
        Ivar *ivars = class_copyIvarList(currentClass, &ivarCount);
        
        for (unsigned int i = 0; i < ivarCount; i++) {
            Ivar ivar = ivars[i];
            NSString *ivarName = @(ivar_getName(ivar));
            NSString *ivarType = @(ivar_getTypeEncoding(ivar));
            
            // 只考虑对象类型的引用
            if ([ivarType hasPrefix:@"@"]) {
                id value = nil;
                @try {
                    value = object_getIvar(object, ivar);
                } @catch (NSException *exception) {
                    continue;
                }
                
                if (value) {
                    NSMutableDictionary *refInfo = [NSMutableDictionary dictionary];
                    refInfo[@"name"] = ivarName;
                    refInfo[@"class"] = NSStringFromClass([value class]);
                    refInfo[@"address"] = [NSString stringWithFormat:@"%p", value];
                    
                    // 这里简单粗暴地根据类型名称来判断强弱引用，实际上更复杂
                    if ([ivarType containsString:@"__weak"]) {
                        [weakReferences addObject:refInfo];
                    } else {
                        [strongReferences addObject:refInfo];
                    }
                }
            }
        }
        
        free(ivars);
        currentClass = class_getSuperclass(currentClass);
    }
    
    result[@"strongReferences"] = strongReferences;
    result[@"weakReferences"] = weakReferences;
    
    return result;
}

+ (NSDictionary *)inspectObjectMemoryValues:(id)object {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    if (!object) {
        return @{@"error": @"Object is nil"};
    }
    
    // 获取对象的类
    Class cls = object_getClass(object);
    result[@"class"] = NSStringFromClass(cls);
    
    // 获取实例大小
    size_t instanceSize = class_getInstanceSize(cls);
    result[@"instanceSize"] = @(instanceSize);
    
    // 内存地址
    result[@"address"] = [NSString stringWithFormat:@"%p", object];
    
    // 获取ISA指针
    void *isaPtr = *(void **)(__bridge void *)object;
    result[@"isa"] = [NSString stringWithFormat:@"%p", isaPtr];
    
    // 从内存中读取原始字节
    NSMutableArray *bytesArray = [NSMutableArray array];
    const unsigned char *bytes = (const unsigned char *)(__bridge void *)object;
    
    for (size_t i = 0; i < instanceSize; i++) {
        [bytesArray addObject:@(bytes[i])];
    }
    
    result[@"rawBytes"] = bytesArray;
    
    return result;
}

@end