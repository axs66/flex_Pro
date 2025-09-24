#import "RTBClassAnalyzer.h"
#import <objc/runtime.h>

@implementation RTBClassAnalyzer

- (NSDictionary *)analyzeClassHierarchy:(Class)cls {
    NSMutableDictionary *hierarchy = [NSMutableDictionary new];
    
    // 获取父类链
    NSArray *superclassChain = [self getSuperclassChain:cls];
    hierarchy[@"superclasses"] = superclassChain;
    
    // 获取子类
    NSArray *subclasses = [self getSubclasses:cls];
    hierarchy[@"subclasses"] = subclasses;
    
    // 获取协议信息
    NSArray *protocols = [self analyzeProtocolConformance:cls];
    hierarchy[@"protocols"] = protocols;
    
    // 获取类关系
    NSDictionary *dependencies = [self analyzeClassDependencies:cls];
    hierarchy[@"dependencies"] = dependencies;
    
    return hierarchy;
}

- (NSArray *)analyzeProtocolConformance:(Class)cls {
    unsigned int count = 0;
    __unsafe_unretained Protocol **protocolList = class_copyProtocolList(cls, &count);
    NSMutableArray *protocols = [NSMutableArray arrayWithCapacity:count];
    
    for (unsigned int i = 0; i < count; i++) {
        Protocol *protocol = protocolList[i];
        NSString *protocolName = NSStringFromProtocol(protocol);
        
        // 分析协议方法实现情况
        NSMutableDictionary *protocolInfo = [NSMutableDictionary dictionary];
        protocolInfo[@"name"] = protocolName;
        
        // 获取必须实现和可选实现的方法
        protocolInfo[@"requiredMethods"] = [self getProtocolMethods:protocol required:YES];
        protocolInfo[@"optionalMethods"] = [self getProtocolMethods:protocol required:NO];
        
        [protocols addObject:protocolInfo];
    }
    
    free(protocolList);
    return protocols;
}

- (NSDictionary *)analyzeClassDependencies:(Class)cls {
    NSMutableDictionary *dependencies = [NSMutableDictionary new];
    
    // 分析实例变量依赖
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    NSMutableArray *ivarDependencies = [NSMutableArray array];
    
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *ivarName = ivar_getName(ivar);
        const char *ivarType = ivar_getTypeEncoding(ivar);
        
        NSMutableDictionary *ivarInfo = [NSMutableDictionary dictionary];
        ivarInfo[@"name"] = @(ivarName);
        ivarInfo[@"type"] = @(ivarType);
        
        [ivarDependencies addObject:ivarInfo];
    }
    
    free(ivars);
    dependencies[@"ivars"] = ivarDependencies;
    
    return dependencies;
}

- (NSArray *)getSuperclassChain:(Class)cls {
    NSMutableArray *hierarchy = [NSMutableArray array];
    
    Class currentClass = cls;
    while (currentClass) {
        [hierarchy addObject:NSStringFromClass(currentClass)];
        currentClass = class_getSuperclass(currentClass);
    }
    
    return hierarchy;
}

- (NSArray *)getSubclasses:(Class)cls {
    NSMutableArray *result = [NSMutableArray array];
    
    unsigned int classCount;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class superClass = classes[i];
        
        do {
            superClass = class_getSuperclass(superClass);
            
            if (superClass == cls) {
                [result addObject:classes[i]];
                break;
            }
        } while (superClass);
    }
    
    free(classes);
    
    return result;
}

- (NSArray *)getProtocolMethods:(Protocol *)protocol required:(BOOL)required {
    NSMutableArray *methods = [NSMutableArray array];
    
    unsigned int methodCount = 0;
    struct objc_method_description *methodList = protocol_copyMethodDescriptionList(protocol, required, YES, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        struct objc_method_description method = methodList[i];
        NSString *methodName = NSStringFromSelector(method.name);
        [methods addObject:methodName];
    }
    
    if (methodList) {
        free(methodList);
    }
    
    return methods;
}

- (NSDictionary *)getProtocolMethodImplementations:(Class)cls {
    if (!cls) return @{};
    
    NSMutableDictionary *implementationInfo = [NSMutableDictionary dictionary];
    unsigned int protocolCount = 0;
    __unsafe_unretained Protocol **protocols = class_copyProtocolList(cls, &protocolCount);
    
    for (unsigned int i = 0; i < protocolCount; i++) {
        Protocol *protocol = protocols[i];
        NSString *protocolName = NSStringFromProtocol(protocol);
        
        // 获取必需的实例方法
        NSMutableArray *requiredInstanceMethods = [NSMutableArray array];
        unsigned int methodCount = 0;
        struct objc_method_description *methods = protocol_copyMethodDescriptionList(protocol, YES, YES, &methodCount);
        
        for (unsigned int j = 0; j < methodCount; j++) {
            SEL selector = methods[j].name;
            NSString *methodName = NSStringFromSelector(selector);
            BOOL isImplemented = class_respondsToSelector(cls, selector);
            
            [requiredInstanceMethods addObject:@{
                @"name": methodName,
                @"implemented": @(isImplemented)
            }];
        }
        
        free(methods);
        
        // 获取可选的实例方法
        NSMutableArray *optionalInstanceMethods = [NSMutableArray array];
        methodCount = 0;
        methods = protocol_copyMethodDescriptionList(protocol, NO, YES, &methodCount);
        
        for (unsigned int j = 0; j < methodCount; j++) {
            SEL selector = methods[j].name;
            NSString *methodName = NSStringFromSelector(selector);
            BOOL isImplemented = class_respondsToSelector(cls, selector);
            
            [optionalInstanceMethods addObject:@{
                @"name": methodName,
                @"implemented": @(isImplemented)
            }];
        }
        
        free(methods);
        
        // 获取必需的类方法
        NSMutableArray *requiredClassMethods = [NSMutableArray array];
        methodCount = 0;
        methods = protocol_copyMethodDescriptionList(protocol, YES, NO, &methodCount);
        Class metaClass = object_getClass(cls);
        
        for (unsigned int j = 0; j < methodCount; j++) {
            SEL selector = methods[j].name;
            NSString *methodName = NSStringFromSelector(selector);
            BOOL isImplemented = class_respondsToSelector(metaClass, selector);
            
            [requiredClassMethods addObject:@{
                @"name": methodName,
                @"implemented": @(isImplemented)
            }];
        }
        
        free(methods);
        
        // 获取可选的类方法
        NSMutableArray *optionalClassMethods = [NSMutableArray array];
        methodCount = 0;
        methods = protocol_copyMethodDescriptionList(protocol, NO, NO, &methodCount);
        
        for (unsigned int j = 0; j < methodCount; j++) {
            SEL selector = methods[j].name;
            NSString *methodName = NSStringFromSelector(selector);
            BOOL isImplemented = class_respondsToSelector(metaClass, selector);
            
            [optionalClassMethods addObject:@{
                @"name": methodName,
                @"implemented": @(isImplemented)
            }];
        }
        
        free(methods);
        
        implementationInfo[protocolName] = @{
            @"requiredInstanceMethods": requiredInstanceMethods,
            @"optionalInstanceMethods": optionalInstanceMethods,
            @"requiredClassMethods": requiredClassMethods,
            @"optionalClassMethods": optionalClassMethods
        };
    }
    
    free(protocols);
    return implementationInfo;
}

- (NSArray *)getAssociatedClasses:(Class)cls {
    if (!cls) return @[];
    
    NSMutableArray *associatedClasses = [NSMutableArray array];
    
    // 分析类的实例变量引用的类
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *typeEncoding = ivar_getTypeEncoding(ivar);
        NSString *type = @(typeEncoding);
        
        // 查找类型中的对象引用 (格式如 @"ClassName")
        if ([type hasPrefix:@"@\""]) {
            NSString *className = [type substringWithRange:NSMakeRange(2, type.length - 3)];
            Class referencedClass = NSClassFromString(className);
            if (referencedClass && ![associatedClasses containsObject:referencedClass]) {
                [associatedClasses addObject:referencedClass];
            }
        }
    }
    
    free(ivars);
    
    // 分析类的属性引用的类
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    
    for (unsigned int i = 0; i < propertyCount; i++) {
        objc_property_t property = properties[i];
        
        unsigned int attrCount = 0;
        objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
        
        for (unsigned int j = 0; j < attrCount; j++) {
            if (strcmp(attrs[j].name, "T") == 0) {
                NSString *type = @(attrs[j].value);
                
                if ([type hasPrefix:@"@\""]) {
                    NSString *className = [type substringWithRange:NSMakeRange(2, type.length - 3)];
                    Class referencedClass = NSClassFromString(className);
                    if (referencedClass && ![associatedClasses containsObject:referencedClass]) {
                        [associatedClasses addObject:referencedClass];
                    }
                }
                break;
            }
        }
        
        free(attrs);
    }
    
    free(properties);
    
    return associatedClasses;
}

@end