#import "RTBClassReferenceAnalyzer.h"
#import <objc/runtime.h>

@implementation RTBClassReferenceAnalyzer

+ (NSDictionary *)getClassDependencies:(Class)cls {
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
    
    // 检查Ivars中可能引用的类
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *ivarType = ivar_getTypeEncoding(ivar);
        NSString *typeString = @(ivarType);
        
        // 尝试提取类名
        NSArray *possibleClasses = [self extractClassNamesFromTypeEncoding:typeString];
        [importedClasses addObjectsFromArray:possibleClasses];
    }
    
    free(ivars);
    
    // 检查属性
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    
    for (unsigned int i = 0; i < propertyCount; i++) {
        objc_property_t property = properties[i];
        
        unsigned int attrCount;
        objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
        
        for (unsigned int j = 0; j < attrCount; j++) {
            if (strcmp(attrs[j].name, "T") == 0) {
                NSString *typeEncoding = @(attrs[j].value);
                NSArray *classes = [self extractClassNamesFromTypeEncoding:typeEncoding];
                [importedClasses addObjectsFromArray:classes];
                break;
            }
        }
        
        free(attrs);
    }
    
    free(properties);
    
    // 检查方法参数和返回值
    unsigned int methodCount;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        const char *returnType = method_copyReturnType(method);
        
        if (returnType) {
            NSString *returnTypeString = @(returnType);
            NSArray *classes = [self extractClassNamesFromTypeEncoding:returnTypeString];
            [importedClasses addObjectsFromArray:classes];
            free((void*)returnType);
        }
        
        unsigned int argCount = method_getNumberOfArguments(method);
        
        // 从索引2开始，因为0是self，1是_cmd
        for (unsigned int j = 2; j < argCount; j++) {
            char *argType = method_copyArgumentType(method, j);
            if (argType) {
                NSString *argTypeString = @(argType);
                NSArray *classes = [self extractClassNamesFromTypeEncoding:argTypeString];
                [importedClasses addObjectsFromArray:classes];
                free(argType);
            }
        }
    }
    
    free(methods);
    
    // 过滤和去重
    NSSet *uniqueImportedClasses = [NSSet setWithArray:importedClasses];
    NSSet *uniqueProtocols = [NSSet setWithArray:referencedProtocols];
    
    dependencies[@"importedClasses"] = [uniqueImportedClasses allObjects];
    dependencies[@"protocols"] = [uniqueProtocols allObjects];
    
    return dependencies;
}

+ (NSArray *)extractClassNamesFromTypeEncoding:(NSString *)typeEncoding {
    NSMutableArray *classNames = [NSMutableArray array];
    
    // 检查对象类型，格式为"@\"ClassName\""
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"@\"([^\"]*)\"" options:0 error:nil];
    NSArray *matches = [regex matchesInString:typeEncoding options:0 range:NSMakeRange(0, typeEncoding.length)];
    
    for (NSTextCheckingResult *match in matches) {
        if (match.range.location != NSNotFound && match.numberOfRanges > 1) {
            NSRange classNameRange = [match rangeAtIndex:1];
            NSString *className = [typeEncoding substringWithRange:classNameRange];
            if (className.length > 0) {
                [classNames addObject:className];
            }
        }
    }
    
    return classNames;
}

+ (NSDictionary *)buildClassDependencyTree:(Class)rootClass maxDepth:(NSInteger)depth {
    NSMutableDictionary *tree = [NSMutableDictionary dictionary];
    NSMutableSet *visitedClasses = [NSMutableSet set];
    
    [self buildClassDependencyTreeRecursive:rootClass 
                                       tree:tree 
                              visitedClasses:visitedClasses 
                                 currentDepth:0 
                                    maxDepth:depth];
    
    return tree;
}

+ (void)buildClassDependencyTreeRecursive:(Class)cls 
                                     tree:(NSMutableDictionary *)tree 
                            visitedClasses:(NSMutableSet *)visitedClasses 
                               currentDepth:(NSInteger)currentDepth 
                                  maxDepth:(NSInteger)maxDepth {
    if (!cls || currentDepth > maxDepth || [visitedClasses containsObject:NSStringFromClass(cls)]) {
        return;
    }
    
    [visitedClasses addObject:NSStringFromClass(cls)];
    
    NSDictionary *dependencies = [self getClassDependencies:cls];
    
    NSMutableDictionary *node = [NSMutableDictionary dictionary];
    node[@"className"] = NSStringFromClass(cls);
    node[@"dependencies"] = dependencies;
    
    if (currentDepth < maxDepth) {
        NSMutableDictionary *children = [NSMutableDictionary dictionary];
        
        for (NSString *importedClass in dependencies[@"importedClasses"]) {
            Class childClass = NSClassFromString(importedClass);
            if (childClass && ![visitedClasses containsObject:importedClass]) {
                [self buildClassDependencyTreeRecursive:childClass 
                                                  tree:children 
                                         visitedClasses:visitedClasses 
                                            currentDepth:currentDepth + 1 
                                               maxDepth:maxDepth];
            }
        }
        
        if (children.count > 0) {
            node[@"children"] = children;
        }
    }
    
    tree[NSStringFromClass(cls)] = node;
}

+ (NSArray *)getSubclasses:(Class)parentClass {
    NSMutableArray *result = [NSMutableArray array];
    
    unsigned int classCount;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class superClass = classes[i];
        
        do {
            superClass = class_getSuperclass(superClass);
            
            if (superClass == parentClass) {
                [result addObject:classes[i]];
                break;
            }
        } while (superClass);
    }
    
    free(classes);
    
    return result;
}

+ (NSDictionary *)checkCyclicReferences:(Class)cls {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSMutableSet *path = [NSMutableSet set];
    NSMutableArray *cycles = [NSMutableArray array];
    
    [self detectCycles:cls path:path cycles:cycles visited:[NSMutableSet set]];
    
    result[@"cycles"] = cycles;
    return result;
}

+ (void)detectCycles:(Class)cls 
                path:(NSMutableSet *)path 
              cycles:(NSMutableArray *)cycles 
             visited:(NSMutableSet *)visited {
    NSString *className = NSStringFromClass(cls);
    
    if ([path containsObject:className]) {
        [cycles addObject:[path allObjects]];
        return;
    }
    
    if ([visited containsObject:className]) {
        return;
    }
    
    [visited addObject:className];
    [path addObject:className];
    
    NSDictionary *dependencies = [self getClassDependencies:cls];
    NSArray *importedClasses = dependencies[@"importedClasses"];
    
    for (NSString *importedClass in importedClasses) {
        Class childClass = NSClassFromString(importedClass);
        if (childClass) {
            [self detectCycles:childClass path:path cycles:cycles visited:visited];
        }
    }
    
    [path removeObject:className];
}

@end