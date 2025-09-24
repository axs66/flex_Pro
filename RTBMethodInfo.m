#import "RTBMethodInfo.h"
#import <UIKit/UIKit.h> 

@implementation RTBMethodInfo

+ (instancetype)methodInfoWithMethod:(Method)method 
                             isClass:(BOOL)isClass 
                      declaringClass:(Class)declaringClass {
    RTBMethodInfo *info = [[RTBMethodInfo alloc] init];
    info.method = method;
    info.type = isClass ? RTBMethodTypeClass : RTBMethodTypeInstance;
    info.declaringClass = declaringClass;
    info.name = NSStringFromSelector(method_getName(method));
    info.signature = [NSString stringWithUTF8String:method_getTypeEncoding(method)];
    info.category = [self determineCategoryForMethod:info];
    return info;
}

+ (RTBMethodCategory)determineCategoryForMethod:(RTBMethodInfo *)info {
    NSString *name = info.name;
    
    // 生命周期方法
    if ([name hasPrefix:@"init"] || 
        [name isEqualToString:@"dealloc"] ||
        [name hasPrefix:@"awake"] || 
        [name hasPrefix:@"view"] ||
        [name hasPrefix:@"layer"]) {
        return RTBMethodCategoryLifecycle;
    }
    
    // UI相关方法
    if ([name hasPrefix:@"set"] && 
        ([name containsString:@"Color"] ||
         [name containsString:@"Font"] ||
         [name containsString:@"Frame"] ||
         [name containsString:@"Bounds"] ||
         [name containsString:@"Image"])) {
        return RTBMethodCategoryUIKit;
    }
    
    // 访问器方法
    if ([name hasPrefix:@"set"] && name.length > 3) {
        // 可能是setter
        return RTBMethodCategoryAccessors;
    }
    
    // 现在 UITableViewDelegate 和 UICollectionViewDelegate 协议将被正确识别
    if ([info.declaringClass conformsToProtocol:@protocol(UITableViewDelegate)] ||
        [info.declaringClass conformsToProtocol:@protocol(UICollectionViewDelegate)] ||
        [name containsString:@"delegate"]) {
        return RTBMethodCategoryDelegate;
    }
    
    return RTBMethodCategoryCustom;
}

- (void *)implementation {
    return method_getImplementation(self.method);
}

- (NSArray<NSString*> *)argumentTypes {
    NSMutableArray *types = [NSMutableArray array];
    unsigned int argCount = method_getNumberOfArguments(self.method);
    
    // 跳过self和_cmd
    for (unsigned int i = 2; i < argCount; i++) {
        char argType[256];
        method_getArgumentType(self.method, i, argType, sizeof(argType));
        [types addObject:[NSString stringWithUTF8String:argType]];
    }
    
    return types;
}

- (NSString *)returnType {
    char returnType[256];
    method_getReturnType(self.method, returnType, sizeof(returnType));
    return [NSString stringWithUTF8String:returnType];
}

- (BOOL)isInitializer {
    return [self.name hasPrefix:@"init"];
}

- (BOOL)isAccessor {
    return (self.category == RTBMethodCategoryAccessors);
}

- (BOOL)isUIKit {
    return (self.category == RTBMethodCategoryUIKit);
}

- (BOOL)isDelegateMethod {
    return (self.category == RTBMethodCategoryDelegate);
}

- (BOOL)isOverridingMethod:(RTBMethodInfo *)otherMethod {
    // 方法名相同才可能是覆盖
    if (![self.name isEqualToString:otherMethod.name]) {
        return NO;
    }
    
    // 不是同一个类才可能是覆盖
    if (self.declaringClass == otherMethod.declaringClass) {
        return NO;
    }
    
    // 类型必须匹配
    if (self.type != otherMethod.type) {
        return NO;
    }
    
    // 检查继承关系
    Class currentClass = self.declaringClass;
    while ((currentClass = class_getSuperclass(currentClass))) {
        if (currentClass == otherMethod.declaringClass) {
            return YES;
        }
    }
    
    return NO;
}

@end