#import "RTBMemoryAnalyzer.h"
#import <objc/runtime.h>

@implementation RTBMemoryAnalyzer

- (NSDictionary *)analyzeObjectMemoryLayout:(id)object {
    NSMutableDictionary *layout = [NSMutableDictionary dictionary];
    Class cls = object_getClass(object);
    
    // 基本信息
    layout[@"class"] = NSStringFromClass(cls);
    layout[@"size"] = @(class_getInstanceSize(cls));
    
    // 分析实例变量
    NSMutableArray *ivars = [NSMutableArray array];
    unsigned int ivarCount;
    Ivar *ivarList = class_copyIvarList(cls, &ivarCount);
    
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivarList[i];
        NSString *name = @(ivar_getName(ivar));
        NSString *type = @(ivar_getTypeEncoding(ivar));
        ptrdiff_t offset = ivar_getOffset(ivar);
        
        [ivars addObject:@{
            @"name": name,
            @"type": type,
            @"offset": @(offset),
            @"value": [self getIvarValue:ivar fromObject:object]
        }];
    }
    
    free(ivarList);
    layout[@"ivars"] = ivars;
    
    return layout;
}

- (id)getIvarValue:(Ivar)ivar fromObject:(id)object {
    const char *type = ivar_getTypeEncoding(ivar);
    
    // 读取不同类型的值
    if (strcmp(type, @encode(id)) == 0) {
        // 使用 object_getIvar 替代 object_getInstanceVariable (ARC兼容)
        return object_getIvar(object, ivar);
    }
    // 可以添加其他类型的处理...
    
    return @"<未知类型>";
}

- (NSDictionary *)analyzeClassMemoryLayout:(Class)cls {
    NSMutableDictionary *layout = [NSMutableDictionary dictionary];
    
    // 类基本信息
    layout[@"name"] = NSStringFromClass(cls);
    layout[@"superclass"] = NSStringFromClass(class_getSuperclass(cls));
    layout[@"instanceSize"] = @(class_getInstanceSize(cls));
    
    // 分析方法区
    unsigned int methodCount;
    Method *methods = class_copyMethodList(cls, &methodCount);
    NSMutableArray *methodLayouts = [NSMutableArray array];
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        [methodLayouts addObject:@{
            @"name": NSStringFromSelector(method_getName(method)),
            @"implementation": [NSString stringWithFormat:@"%p", method_getImplementation(method)],
            @"typeEncoding": @(method_getTypeEncoding(method))
        }];
    }
    
    free(methods);
    layout[@"methods"] = methodLayouts;
    
    return layout;
}

- (NSArray *)getObjectStrongReferences:(id)object {
    NSMutableArray *references = [NSMutableArray array];
    Class cls = object_getClass(object);
    
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *type = ivar_getTypeEncoding(ivar);
        
        // 检查是否是对象类型
        if (strcmp(type, @encode(id)) == 0) {
            // 使用 object_getIvar 替代 object_getInstanceVariable
            id value = object_getIvar(object, ivar);
            
            if (value) {
                [references addObject:@{
                    @"name": @(ivar_getName(ivar)),
                    @"class": NSStringFromClass([value class])
                }];
            }
        }
    }
    
    free(ivars);
    return references;
}

@end