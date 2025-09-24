#import "RTBClassPerformanceAnalyzer.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <malloc/malloc.h>

// 记录方法调用的结构体
typedef struct {
    Class cls;
    SEL selector;
    int count;
} RTBMethodCallRecord;

// 全局变量跟踪调用次数
static NSMutableDictionary *methodCallCounts;
static NSMutableDictionary *propertyAccessCounts;

@implementation RTBClassPerformanceAnalyzer

+ (void)initialize {
    if (self == [RTBClassPerformanceAnalyzer class]) {
        methodCallCounts = [NSMutableDictionary dictionary];
        propertyAccessCounts = [NSMutableDictionary dictionary];
    }
}

+ (NSDictionary *)analyzeMethodCallsForClass:(Class)cls {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSMutableArray *methodList = [NSMutableArray array];
    
    // 获取实例方法
    unsigned int count;
    Method *methods = class_copyMethodList(cls, &count);
    
    for (unsigned int i = 0; i < count; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        NSString *methodName = NSStringFromSelector(selector);
        
        // 计算方法的参数个数
        unsigned int argsCount = method_getNumberOfArguments(method);
        
        // 获取方法的实现
        __unused IMP imp = method_getImplementation(method);
        
        // 获取方法的类型编码
        const char *typeEncoding = method_getTypeEncoding(method);
        
        [methodList addObject:@{
            @"name": methodName,
            @"argumentsCount": @(argsCount - 2), // 减去self和_cmd
            @"typeEncoding": typeEncoding ? @(typeEncoding) : @"unknown"
        }];
    }
    
    free(methods);
    
    // 获取类方法
    Class metaClass = object_getClass(cls);
    Method *classMethods = class_copyMethodList(metaClass, &count);
    
    NSMutableArray *classMethodList = [NSMutableArray array];
    for (unsigned int i = 0; i < count; i++) {
        Method method = classMethods[i];
        SEL selector = method_getName(method);
        NSString *methodName = NSStringFromSelector(selector);
        
        // 计算方法的参数个数
        unsigned int argsCount = method_getNumberOfArguments(method);
        
        // 获取方法的实现
        __unused IMP imp = method_getImplementation(method);
        
        // 获取方法的类型编码
        const char *typeEncoding = method_getTypeEncoding(method);
        
        [classMethodList addObject:@{
            @"name": methodName,
            @"argumentsCount": @(argsCount - 2), // 减去self和_cmd
            @"typeEncoding": typeEncoding ? @(typeEncoding) : @"unknown"
        }];
    }
    
    free(classMethods);
    
    result[@"instanceMethods"] = methodList;
    result[@"classMethods"] = classMethodList;
    
    return result;
}

+ (NSDictionary *)analyzeMemoryUsageForClass:(Class)cls {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    // 获取实例大小
    size_t instanceSize = class_getInstanceSize(cls);
    result[@"instanceSize"] = @(instanceSize);
    
    // 获取Ivars并分析内存占用
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    NSMutableArray *ivarsList = [NSMutableArray array];
    
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        NSString *ivarName = @(ivar_getName(ivar));
        NSString *ivarType = @(ivar_getTypeEncoding(ivar));
        ptrdiff_t offset = ivar_getOffset(ivar);
        
        [ivarsList addObject:@{
            @"name": ivarName,
            @"type": ivarType,
            @"offset": @(offset)
        }];
    }
    
    free(ivars);
    result[@"ivars"] = ivarsList;
    
    // 获取属性列表
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    NSMutableArray *propertiesList = [NSMutableArray array];
    
    for (unsigned int i = 0; i < propertyCount; i++) {
        objc_property_t property = properties[i];
        NSString *propertyName = @(property_getName(property));
        
        // 获取属性特性
        unsigned int attrCount;
        objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        
        for (unsigned int j = 0; j < attrCount; j++) {
            attributes[@(attrs[j].name)] = @(attrs[j].value);
        }
        
        free(attrs);
        
        [propertiesList addObject:@{
            @"name": propertyName,
            @"attributes": attributes
        }];
    }
    
    free(properties);
    result[@"properties"] = propertiesList;
    
    return result;
}

+ (NSDictionary *)analyzePropertyAccessForClass:(Class)cls {
    // 这个方法需要动态监控属性访问，完整实现需要使用Method Swizzling
    // 此处返回一个示例结构
    return @{
        @"note": @"需要通过运行时监控才能获取准确数据"
    };
}

@end