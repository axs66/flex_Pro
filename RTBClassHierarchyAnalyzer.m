#import "RTBClassHierarchyAnalyzer.h"
#import <objc/runtime.h>

@implementation RTBClassHierarchyAnalyzer

+ (NSDictionary *)analyzeClassHierarchy:(Class)cls {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    result[@"className"] = NSStringFromClass(cls);
    result[@"superclass"] = class_getSuperclass(cls) ? NSStringFromClass(class_getSuperclass(cls)) : @"(none)";
    result[@"instanceSize"] = @(class_getInstanceSize(cls));
    
    // 分析所有方法
    NSMutableArray *methods = [NSMutableArray array];
    unsigned int methodCount;
    Method *methodList = class_copyMethodList(cls, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methodList[i];
        SEL selector = method_getName(method);
        NSString *selectorName = NSStringFromSelector(selector);
        const char *encoding = method_getTypeEncoding(method);
        
        [methods addObject:@{
            @"name": selectorName,
            @"encoding": encoding ? @(encoding) : @"",
            @"implementation": [NSString stringWithFormat:@"%p", method_getImplementation(method)]
        }];
    }
    free(methodList);
    result[@"methods"] = methods;
    
    // 分析所有协议
    NSMutableArray *protocols = [NSMutableArray array];
    unsigned int protocolCount;
    Protocol * __unsafe_unretained *protocolList = class_copyProtocolList(cls, &protocolCount);
    for (unsigned int i = 0; i < protocolCount; i++) {
        Protocol *protocol = protocolList[i];
        [protocols addObject:@(protocol_getName(protocol))];
    }
    free(protocolList);
    result[@"protocols"] = protocols;
    
    // 分析所有成员变量
    NSMutableArray *ivars = [NSMutableArray array];
    unsigned int ivarCount;
    Ivar *ivarList = class_copyIvarList(cls, &ivarCount);
    for (unsigned int i = 0; i < ivarCount; i++) {
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
    result[@"ivars"] = ivars;
    
    return result;
}

+ (NSString *)typeFromAttributes:(NSString *)attributes {
    // 解析属性类型的简单实现
    if ([attributes hasPrefix:@"T@"]) {
        NSRange range = [attributes rangeOfString:@"\""];
        if (range.location != NSNotFound) {
            NSRange endRange = [attributes rangeOfString:@"\"" options:0 range:NSMakeRange(range.location + 1, attributes.length - range.location - 1)];
            if (endRange.location != NSNotFound) {
                return [attributes substringWithRange:NSMakeRange(range.location + 1, endRange.location - range.location - 1)];
            }
        }
    }
    
    // 基本类型处理
    if ([attributes hasPrefix:@"Ti"]) return @"int";
    if ([attributes hasPrefix:@"Tf"]) return @"float";
    if ([attributes hasPrefix:@"Td"]) return @"double";
    if ([attributes hasPrefix:@"Tl"]) return @"long";
    if ([attributes hasPrefix:@"Tc"]) return @"char";
    if ([attributes hasPrefix:@"Ts"]) return @"short";
    if ([attributes hasPrefix:@"TB"]) return @"BOOL";
    if ([attributes hasPrefix:@"Tq"]) return @"long long";
    if ([attributes hasPrefix:@"T^"]) return @"pointer";
    
    return attributes;
}

// 添加缺失的方法实现
+ (NSArray *)analyzeProtocolConformance:(Class)cls {
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

+ (NSArray *)getSuperclassChain:(Class)cls {
    NSMutableArray *hierarchy = [NSMutableArray array];
    
    Class currentClass = cls;
    while (currentClass) {
        [hierarchy addObject:NSStringFromClass(currentClass)];
        currentClass = class_getSuperclass(currentClass);
    }
    
    return hierarchy;
}

+ (NSArray *)getSubclasses:(Class)cls {
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

+ (NSDictionary *)analyzeClassDependencies:(Class)cls {
    NSMutableDictionary *dependencies = [NSMutableDictionary dictionary];
    NSMutableArray *importedClasses = [NSMutableArray array];
    NSMutableArray *referencedProtocols = [NSMutableArray array];
    
    // 检查父类
    Class superCls = class_getSuperclass(cls);
    if (superCls) {
        [importedClasses addObject:NSStringFromClass(superCls)];
    }
    
    // 检查协议
    unsigned int protocolCount;
    __unsafe_unretained Protocol **protocols = class_copyProtocolList(cls, &protocolCount);
    
    for (unsigned int i = 0; i < protocolCount; i++) {
        Protocol *protocol = protocols[i];
        NSString *protocolName = @(protocol_getName(protocol));
        [referencedProtocols addObject:protocolName];
    }
    
    free(protocols);
    
    // 检查Ivars
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *ivarType = ivar_getTypeEncoding(ivar);
        NSString *typeString = @(ivarType);
        
        // 提取可能的类引用
        if ([typeString rangeOfString:@"@\""].location != NSNotFound) {
            NSString *className = [typeString substringWithRange:NSMakeRange([typeString rangeOfString:@"@\""].location + 2,
                                                               [typeString length] - [typeString rangeOfString:@"@\""].location - 3)];
            if (className.length > 0 && NSClassFromString(className)) {
                [importedClasses addObject:className];
            }
        }
    }
    
    free(ivars);
    
    dependencies[@"importedClasses"] = importedClasses;
    dependencies[@"referencedProtocols"] = referencedProtocols;
    
    return dependencies;
}

+ (NSArray *)getProtocolMethods:(Protocol *)protocol required:(BOOL)required {
    NSMutableArray *methods = [NSMutableArray array];
    
    // 获取实例方法
    unsigned int methodCount;
    struct objc_method_description *methodDescriptions = protocol_copyMethodDescriptionList(protocol, required, YES, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        struct objc_method_description method = methodDescriptions[i];
        NSString *name = NSStringFromSelector(method.name);
        
        [methods addObject:@{
            @"name": name,
            @"instance": @YES
        }];
    }
    
    free(methodDescriptions);
    
    // 获取类方法
    methodCount = 0;
    methodDescriptions = protocol_copyMethodDescriptionList(protocol, required, NO, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        struct objc_method_description method = methodDescriptions[i];
        NSString *name = NSStringFromSelector(method.name);
        
        [methods addObject:@{
            @"name": name,
            @"instance": @NO
        }];
    }
    
    free(methodDescriptions);
    
    return methods;
}

@end