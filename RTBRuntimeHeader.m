//
//  RTBTypeParser.m
//  runtime_cli
//
//  Created by Nicolas Seriot on 02/04/15.
//
//

#import "RTBRuntimeHeader.h"
#import "RTBMethod.h"
#import "RTBClass.h"

#if USE_NEW_DECODER
#import "RTBTypeDecoder2.h"
@compatibility_alias RTBTypeDecoder RTBTypeDecoder2;
#else
#import "RTBTypeDecoder.h"
#endif

OBJC_EXPORT const char *_protocol_getMethodTypeEncoding(Protocol *, SEL, BOOL isRequiredMethod, BOOL isInstanceMethod) __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_6_0);

@implementation RTBRuntimeHeader

+ (NSString *)decodedTypeForEncodedString:(NSString *)s {
    return [RTBTypeDecoder decodeType:s flat:YES];
}

+ (NSString *)descriptionForPropertyWithName:(NSString *)name attributes:(NSString *)attributes displayPropertiesDefaultValues:(BOOL)displayPropertiesDefaultValues {
    
    // https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
    
    NSString *getter = nil;
    NSString *setter = nil;
    NSString *type = nil;
    NSString *atomicity = nil;
    NSString *memory = nil;
    NSString *rw = nil;
    NSString *comment = nil;
    
    NSArray *attributesComponents = [attributes componentsSeparatedByString:@","];
    for(NSString *attribute in attributesComponents) {
        NSAssert([attributes length] >= 2, @"");
        unichar c = [attribute characterAtIndex:0];
        NSString *tail = [attribute substringFromIndex:1];
        if (c == 'R') rw = @"readonly";
        else if (c == 'C') memory = @"copy";
        else if (c == '&') memory = @"retain";
        else if (c == 'G') getter = tail; // custom getter
        else if (c == 'S') setter = tail; // custome setter
        else if (c == 't' || c == 'T') type = [RTBTypeDecoder decodeType:tail flat:YES]; // Specifies the type using old-style encoding
        else if (c == 'D') {} // The property is dynamic (@dynamic)
        else if (c == 'W') {} // The property is a weak reference (__weak)
        else if (c == 'P') {} // The property is eligible for garbage collection
        else if (c == 'N') atomicity = @"nonatomic"; // memory - The property is non-atomic (nonatomic)
        else if (c == 'V') {} // oneway
        else comment = [NSString stringWithFormat:@"/* unknown property attribute: %@ */", attribute];
    }
    
    if(displayPropertiesDefaultValues) {
        if(!atomicity) atomicity = @"atomic";
        if(!rw) rw = @"readwrite";
    }
    
    NSMutableString *ms = [NSMutableString stringWithString:@"@property "];
    
    NSMutableArray *attributesArray = [NSMutableArray array];
    if(getter)    [attributesArray addObject:[NSString stringWithFormat:@"getter=%@", getter]];
    if(setter)    [attributesArray addObject:[NSString stringWithFormat:@"setter=%@", setter]];
    if(atomicity) [attributesArray addObject:atomicity];
    if(rw)        [attributesArray addObject:rw];
    if(memory)    [attributesArray addObject:memory];
    
    if([attributesArray count] > 0) {
        NSString *attributesDescription = [NSString stringWithFormat:@"(%@)", [attributesArray componentsJoinedByString:@", "]];
        [ms appendString:attributesDescription];
        [ms appendFormat:@" "];
    }
    
    [ms appendString:type];
    
    if([type hasSuffix:@"*"] == NO) {
        [ms appendString:@" "];
    }
    
    [ms appendFormat:@"%@;", name];
    
    if(comment)
        [ms appendFormat:@" %@", comment];
    
    return ms;
}

+ (NSString *)descriptionForMethodName:(NSString *)methodName
                            returnType:(NSString *)returnType
                         argumentTypes:(NSArray *)argumentsTypes
                      newlineAfterArgs:(BOOL)newlineAfterArgs
                         isClassMethod:(BOOL)isClassMethod {

    NSString *signAndReturnTypeString = [NSString stringWithFormat:@"%c (%@)", (isClassMethod ? '+' : '-'), returnType];
    
    NSArray *methodNameParts = [methodName componentsSeparatedByString:@":"];
    if([[methodNameParts lastObject] length] == 0) {
        methodNameParts = [methodNameParts subarrayWithRange:NSMakeRange(0, [methodNameParts count]-1)];
    }
    NSAssert([methodNameParts count] > 0, @"");
    
    NSMutableArray *ma = [NSMutableArray array];
    
    __block NSMutableString *ms = [NSMutableString string];
    
    [ms appendString:signAndReturnTypeString];
    
    BOOL hasArgs = [argumentsTypes count] > 2;
    
    __block NSUInteger paddingIndex = 0;

    BOOL hasBadNumberOfArgTypes = (hasArgs && (([methodNameParts count]) != ([argumentsTypes count] - 2)));
    
    [methodNameParts enumerateObjectsUsingBlock:^(NSString *part, NSUInteger i, BOOL *stop) {
        
        [ms appendString:part];
        
        if(hasArgs) {
            NSString *argType = hasBadNumberOfArgTypes ? @"void *" : argumentsTypes[i+2];
            if([argType hasPrefix:@"<"] && [argType hasSuffix:@"> *"]) { // eg. "<MyProtocol> *" -> "id <MyProtocol>"
                argType = [NSString stringWithFormat:@"id %@", [argType substringToIndex:[argType length] - 2]];
            }
            NSString *s = [NSString stringWithFormat:@":(%@)arg%@", argType, @(i+1)];
            
            if(paddingIndex == 0) {
                paddingIndex = [ms length];
            }
            
            paddingIndex = MAX(paddingIndex, [part length]);
            
            [ms appendString:s];
            
            BOOL isLastPart = i == [methodNameParts count] - 1;
            
            if(isLastPart) {
                [ms appendString:@";"];
                if(hasBadNumberOfArgTypes) { // happens on iOS 8.3 in SceneKit.framework -[SCNCameraControlEventHandler rotateWithVector:mode:]
                    NSArray *subArgumentTypes = [argumentsTypes subarrayWithRange:NSMakeRange(2, [argumentsTypes count]-2)];
                    [ms appendFormat:@" // needs %@ arg types, found %@: %@",
                     @([methodNameParts count]),
                     @([subArgumentTypes count]),
                     [subArgumentTypes componentsJoinedByString:@", "]];
                }
            } else {
                [ms appendString:@" "];
            }
        }
        
        [ma addObject:ms];
        ms = [NSMutableString string];
    }];
    
    if([[ma lastObject] hasSuffix:@";"] == NO && hasBadNumberOfArgTypes == NO) {
        [[ma lastObject] appendString:@";"];
    }
    
    NSString *joinerString = @"";
    
    if(newlineAfterArgs) {
        NSMutableArray *ma2 = [NSMutableArray array];
        
        [ma enumerateObjectsUsingBlock:^(NSString *s, NSUInteger idx, BOOL *stop) {
            NSString *part = methodNameParts[idx];
            if(idx == 0) {
                part = [part stringByAppendingString:signAndReturnTypeString];
            }
            NSMutableString *_ms = [NSMutableString string];
            NSInteger padSize = paddingIndex - [part length];
            if(padSize < 0) padSize = 0;
            for(int i = 0; i < padSize; i++) [_ms appendString:@" "];
            NSString *s2 = [_ms stringByAppendingString:s];
            
            [ma2 addObject:s2];
            
        }];
        
        ma = ma2;
        
        joinerString = @"\n";
    }
    
    NSString *s = [ma componentsJoinedByString:joinerString];
    
    if(hasBadNumberOfArgTypes) {
        NSLog(@"-- %@", s);
    }
    
    return s;
}

+ (NSString *)descriptionForProtocol:(Protocol *)protocol selector:(SEL)selector isRequiredMethod:(BOOL)isRequiredMethod isInstanceMethod:(BOOL)isInstanceMethod {
    
    const char *descriptionString = _protocol_getMethodTypeEncoding(protocol, selector, isRequiredMethod, isInstanceMethod);
    NSString *argumentTypesEncodedString = [NSString stringWithCString:descriptionString encoding:NSUTF8StringEncoding];
    NSArray *argumentTypes = [RTBTypeDecoder decodeTypes:argumentTypesEncodedString flat:YES];
    NSString *returnType = [argumentTypes objectAtIndex:0];
    NSString *methodName = NSStringFromSelector(selector);
    
    return [self descriptionForMethodName:methodName
                               returnType:returnType
                            argumentTypes:[argumentTypes subarrayWithRange:NSMakeRange(1, [argumentTypes count]-1)]
                         newlineAfterArgs:NO
                            isClassMethod:(isInstanceMethod == NO)];
}

+ (NSString *)headerForClass:(Class)cls displayPropertiesDefaultValues:(BOOL)displayPropertyValues {
    NSMutableString *header = [NSMutableString string];
    
    // 添加头文件信息
    [header appendFormat:@"// Generated by RuntimeBrowser\n"];
    [header appendFormat:@"// %@\n\n", [NSDate date]];
    
    // 导入父类头文件
    Class superCls = class_getSuperclass(cls);
    if (superCls) {
        [header appendFormat:@"#import \"%@.h\"\n\n", NSStringFromClass(superCls)];
    } else {
        [header appendString:@"#import <Foundation/Foundation.h>\n\n"];
    }
    
    // 添加协议列表
    NSArray *protocols = [self getProtocolsForClass:cls];
    if (protocols.count > 0) {
        [header appendString:@"@protocols("];
        [header appendString:[protocols componentsJoinedByString:@", "]];
        [header appendString:@")\n\n"];
    }
    
    // 生成类接口声明
    [header appendFormat:@"@interface %@ : %@", NSStringFromClass(cls), 
                        superCls ? NSStringFromClass(superCls) : @"NSObject"];
    
    // 添加属性声明
    [self appendProperties:cls toHeader:header withDefaultValues:displayPropertyValues];
    
    // 添加方法声明
    [self appendMethods:cls toHeader:header];
    
    // 添加实例变量声明
    [self appendIvars:cls toHeader:header];
    
    [header appendString:@"@end\n"];
    
    return header;
}

// 添加缺少的方法实现

// 添加缺少的类方法
+ (void)appendProperties:(Class)cls toHeader:(NSMutableString *)header withDefaultValues:(BOOL)displayDefaultValues {
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    
    if (propertyCount > 0) {
        [header appendString:@"\n// Properties\n"];
        for (unsigned int i = 0; i < propertyCount; i++) {
            objc_property_t property = properties[i];
            const char *propertyName = property_getName(property);
            const char *propertyAttributes = property_getAttributes(property);
            
            NSString *propertyString = [self descriptionForPropertyWithName:@(propertyName)
                                                              attributes:@(propertyAttributes)
                                          displayPropertiesDefaultValues:displayDefaultValues];
            [header appendFormat:@"%@\n", propertyString];
        }
    }
    free(properties);
}

+ (void)appendMethods:(Class)cls toHeader:(NSMutableString *)header {
    // 实例方法
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    if (methodCount > 0) {
        [header appendString:@"\n// Instance Methods\n"];
        for (unsigned int i = 0; i < methodCount; i++) {
            Method method = methods[i];
            SEL selector = method_getName(method);
            const char *typeEncoding = method_getTypeEncoding(method);
            
            [header appendFormat:@"- (%s)%s;\n", typeEncoding, sel_getName(selector)];
        }
    }
    free(methods);
    
    // 类方法
    methodCount = 0;
    methods = class_copyMethodList(object_getClass(cls), &methodCount);
    
    if (methodCount > 0) {
        [header appendString:@"\n// Class Methods\n"];
        for (unsigned int i = 0; i < methodCount; i++) {
            Method method = methods[i];
            SEL selector = method_getName(method);
            const char *typeEncoding = method_getTypeEncoding(method);
            
            [header appendFormat:@"+ (%s)%s;\n", typeEncoding, sel_getName(selector)];
        }
    }
    free(methods);
}

+ (void)appendIvars:(Class)cls toHeader:(NSMutableString *)header {
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    
    if (ivarCount > 0) {
        [header appendString:@"\n// Instance Variables\n"];
        [header appendString:@"{\n"];
        for (unsigned int i = 0; i < ivarCount; i++) {
            Ivar ivar = ivars[i];
            const char *ivarName = ivar_getName(ivar);
            const char *ivarType = ivar_getTypeEncoding(ivar);
            
            [header appendFormat:@"    %s %s;\n", ivarType, ivarName];
        }
        [header appendString:@"}\n"];
    }
    free(ivars);
}

// 修复ARC问题的方法
+ (NSString *)getTypeString:(const char *)type {
    if (!type) return @"id";
    
    NSString *typeStr = @(type);
    
    // 常见类型转换
    if ([typeStr hasPrefix:@"@\""] && [typeStr hasSuffix:@"\""]) {
        // 对象类型
        return [typeStr substringWithRange:NSMakeRange(2, typeStr.length - 3)];
    } else if ([typeStr isEqualToString:@"i"]) {
        return @"int";
    } else if ([typeStr isEqualToString:@"l"]) {
        return @"long";
    } else if ([typeStr isEqualToString:@"c"]) {
        return @"BOOL";
    } else if ([typeStr isEqualToString:@"f"]) {
        return @"float";
    } else if ([typeStr isEqualToString:@"d"]) {
        return @"double";
    } else if ([typeStr isEqualToString:@"v"]) {
        return @"void";
    } else if ([typeStr isEqualToString:@"@"]) {
        return @"id";
    } else if ([typeStr hasPrefix:@"^"]) {
        // 修复ARC问题
        NSString *restOfType = [typeStr substringFromIndex:1];
        NSString *pointedType = [self getTypeString:[restOfType UTF8String]];
        return [NSString stringWithFormat:@"%@ *", pointedType];
    }
    
    return typeStr;
}

// 添加获取类的协议方法
+ (NSArray *)getProtocolsForClass:(Class)cls {
    if (!cls) return @[];
    
    unsigned int count = 0;
    __unsafe_unretained Protocol **protocolList = class_copyProtocolList(cls, &count);
    
    NSMutableArray *protocols = [NSMutableArray arrayWithCapacity:count];
    for (unsigned int i = 0; i < count; i++) {
        Protocol *protocol = protocolList[i];
        [protocols addObject:NSStringFromProtocol(protocol)];
    }
    
    free(protocolList);
    return protocols;
}

// 实现协议头文件生成方法
+ (NSString *)headerForProtocol:(RTBProtocol *)protocol {
    if (!protocol) return @"";
    
    NSMutableString *header = [NSMutableString string];
    [header appendFormat:@"@protocol %@", protocol.protocolName];
    
    // 添加继承的协议
    NSArray *adoptedProtocols = [protocol sortedAdoptedProtocolsNames];
    if (adoptedProtocols.count > 0) {
        [header appendString:@" <"];
        [header appendString:[adoptedProtocols componentsJoinedByString:@", "]];
        [header appendString:@">"];
    }
    
    [header appendString:@"\n\n"];
    
    // 添加必须实现的实例方法
    NSArray *requiredInstanceMethods = [protocol sortedMethodsRequired:YES instanceMethods:YES];
    if (requiredInstanceMethods.count > 0) {
        for (NSDictionary *method in requiredInstanceMethods) {
            [header appendFormat:@"- %@;\n", method[@"description"]];
        }
        [header appendString:@"\n"];
    }
    
    // 添加可选实例方法
    NSArray *optionalInstanceMethods = [protocol sortedMethodsRequired:NO instanceMethods:YES];
    if (optionalInstanceMethods.count > 0) {
        [header appendString:@"@optional\n"];
        for (NSDictionary *method in optionalInstanceMethods) {
            [header appendFormat:@"- %@;\n", method[@"description"]];
        }
        [header appendString:@"\n"];
    }
    
    // 添加必须实现的类方法
    NSArray *requiredClassMethods = [protocol sortedMethodsRequired:YES instanceMethods:NO];
    if (requiredClassMethods.count > 0) {
        [header appendString:@"@required\n"];
        for (NSDictionary *method in requiredClassMethods) {
            [header appendFormat:@"+ %@;\n", method[@"description"]];
        }
        [header appendString:@"\n"];
    }
    
    // 添加可选类方法
    NSArray *optionalClassMethods = [protocol sortedMethodsRequired:NO instanceMethods:NO];
    if (optionalClassMethods.count > 0) {
        [header appendString:@"@optional\n"];
        for (NSDictionary *method in optionalClassMethods) {
            [header appendFormat:@"+ %@;\n", method[@"description"]];
        }
        [header appendString:@"\n"];
    }
    
    [header appendString:@"@end"];
    
    return header;
}
@end
