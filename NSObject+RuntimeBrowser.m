#import "NSObject+RuntimeBrowser.h"
#import <objc/runtime.h>

@implementation NSObject (RuntimeBrowser)

+ (void)rb_swizzleClassMethodWithOriginSel:(SEL)oriSel swizzledSel:(SEL)swiSel {
    Class cls = object_getClass(self);
    
    Method originMethod = class_getClassMethod(cls, oriSel);
    Method swizzledMethod = class_getClassMethod(cls, swiSel);
    
    [self rb_swizzleMethodWithOriginSel:oriSel oriMethod:originMethod swizzledSel:swiSel swizzledMethod:swizzledMethod class:cls];
}

+ (void)rb_swizzleInstanceMethodWithOriginSel:(SEL)oriSel swizzledSel:(SEL)swiSel {
    Method originMethod = class_getInstanceMethod(self, oriSel);
    Method swizzledMethod = class_getInstanceMethod(self, swiSel);
    
    [self rb_swizzleMethodWithOriginSel:oriSel oriMethod:originMethod swizzledSel:swiSel swizzledMethod:swizzledMethod class:self];
}

+ (void)rb_swizzleMethodWithOriginSel:(SEL)oriSel
                            oriMethod:(Method)oriMethod
                          swizzledSel:(SEL)swizzledSel
                       swizzledMethod:(Method)swizzledMethod
                               class:(Class)cls {
    BOOL didAddMethod = class_addMethod(cls, oriSel, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(cls, swizzledSel, method_getImplementation(oriMethod), method_getTypeEncoding(oriMethod));
    } else {
        method_exchangeImplementations(oriMethod, swizzledMethod);
    }
}

- (void)rb_setAssociatedObject:(id)object forKey:(void *)key {
    objc_setAssociatedObject(self, key, object, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)rb_getAssociatedObjectForKey:(void *)key {
    return objc_getAssociatedObject(self, key);
}

- (NSArray *)rtb_allProperties {
    unsigned int count;
    objc_property_t *properties = class_copyPropertyList([self class], &count);
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
    
    for (unsigned int i = 0; i < count; i++) {
        const char *name = property_getName(properties[i]);
        NSString *propertyName = [NSString stringWithUTF8String:name];
        if (propertyName) {
            [result addObject:propertyName];
        }
    }
    
    free(properties);
    return result;
}

- (NSArray *)rtb_allIvars {
    unsigned int count;
    Ivar *ivars = class_copyIvarList([self class], &count);
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
    
    for (unsigned int i = 0; i < count; i++) {
        const char *name = ivar_getName(ivars[i]);
        NSString *ivarName = [NSString stringWithUTF8String:name];
        if (ivarName) {
            [result addObject:ivarName];
        }
    }
    
    free(ivars);
    return result;
}

- (NSArray *)rtb_allMethods {
    unsigned int count;
    Method *methods = class_copyMethodList([self class], &count);
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
    
    for (unsigned int i = 0; i < count; i++) {
        SEL selector = method_getName(methods[i]);
        NSString *methodName = NSStringFromSelector(selector);
        if (methodName) {
            [result addObject:methodName];
        }
    }
    
    free(methods);
    return result;
}

- (NSArray *)rtb_classHierarchy {
    NSMutableArray *hierarchy = [NSMutableArray array];
    Class currentClass = [self class];
    
    while (currentClass) {
        [hierarchy addObject:NSStringFromClass(currentClass)];
        currentClass = class_getSuperclass(currentClass);
    }
    
    return hierarchy;
}

- (BOOL)rtb_respondsToSelector:(SEL)selector {
    // 安全执行respondsToSelector:以避免可能的崩溃
    @try {
        return [self respondsToSelector:selector];
    }
    @catch (NSException *exception) {
        return NO;
    }
}

- (NSString *)rtb_detailedDescription {
    NSMutableString *description = [NSMutableString string];
    
    // 基本信息
    [description appendFormat:@"Object: %@\n", self];
    [description appendFormat:@"Class: %@\n", NSStringFromClass([self class])];
    [description appendFormat:@"Super Class: %@\n", NSStringFromClass([self superclass])];
    
    // 属性
    NSArray *properties = [self rtb_allProperties];
    [description appendFormat:@"\nProperties (%lu):\n", (unsigned long)properties.count];
    for (NSString *property in properties) {
        @try {
            id value = [self valueForKey:property];
            [description appendFormat:@"  %@: %@\n", property, value];
        }
        @catch (NSException *exception) {
            [description appendFormat:@"  %@: <无法访问>\n", property];
        }
    }
    
    // 实例变量
    NSArray *ivars = [self rtb_allIvars];
    [description appendFormat:@"\nIvars (%lu):\n", (unsigned long)ivars.count];
    for (NSString *ivar in ivars) {
        [description appendFormat:@"  %@\n", ivar];
    }
    
    // 方法
    NSArray *methods = [self rtb_allMethods];
    [description appendFormat:@"\nMethods (%lu):\n", (unsigned long)methods.count];
    for (NSString *method in methods) {
        [description appendFormat:@"  %@\n", method];
    }
    
    return description;
}

@end