#import "RTBDynamicInvoker.h"
#import <objc/runtime.h>

@implementation RTBDynamicInvoker

// 实现第一个公共方法
+ (id)invokeMethod:(SEL)selector onTarget:(id)target withArguments:(NSArray *)arguments {
    if (!target || !selector) {
        return nil;
    }
    
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    if (!signature) {
        NSLog(@"方法 %@ 在目标 %@ 上未找到", NSStringFromSelector(selector), [target class]);
        return nil;
    }
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    [invocation setTarget:target];
    
    // 设置参数
    for (NSUInteger i = 0; i < arguments.count && (i + 2) < signature.numberOfArguments; i++) {
        id arg = arguments[i];
        [self setArgument:arg atIndex:i + 2 forInvocation:invocation withSignature:signature];
    }
    
    // 执行调用
    [invocation invoke];
    
    // 如果方法有返回值
    if (signature.methodReturnLength > 0) {
        void *buffer = malloc(signature.methodReturnLength);
        [invocation getReturnValue:buffer];
        
        id returnValue = nil;
        returnValue = [self boxedValueWithBytes:buffer objCType:signature.methodReturnType];
        free(buffer);
        return returnValue;
    }
    
    return nil;
}

// 实现第二个公共方法
+ (id)invokeClassMethod:(SEL)selector onClass:(Class)cls withArguments:(NSArray *)arguments {
    if (!cls || !selector) {
        return nil;
    }
    
    // 类方法实际上是元类的实例方法
    return [self invokeMethod:selector onTarget:cls withArguments:arguments];
}

#pragma mark - 辅助方法

// 设置参数到 NSInvocation
+ (void)setArgument:(id)arg atIndex:(NSUInteger)index forInvocation:(NSInvocation *)invocation withSignature:(NSMethodSignature *)signature {
    const char *argType = [signature getArgumentTypeAtIndex:index];
    
    // 处理不同类型的参数
    if (strcmp(argType, @encode(id)) == 0 || 
        strcmp(argType, @encode(Class)) == 0) {
        [invocation setArgument:&arg atIndex:index];
    }
    else if ([arg isKindOfClass:[NSNumber class]]) {
        NSNumber *number = (NSNumber *)arg;
        
        // 数字类型处理
        if (strcmp(argType, @encode(BOOL)) == 0) {
            BOOL value = [number boolValue];
            [invocation setArgument:&value atIndex:index];
        }
        else if (strcmp(argType, @encode(int)) == 0) {
            int value = [number intValue];
            [invocation setArgument:&value atIndex:index];
        }
        else if (strcmp(argType, @encode(float)) == 0) {
            float value = [number floatValue];
            [invocation setArgument:&value atIndex:index];
        }
        else if (strcmp(argType, @encode(double)) == 0) {
            double value = [number doubleValue];
            [invocation setArgument:&value atIndex:index];
        }
        else {
            // 其他数字类型默认使用 longValue
            long value = [number longValue];
            [invocation setArgument:&value atIndex:index];
        }
    }
    else if (arg == nil) {
        // 处理 nil 参数
        [invocation setArgument:&arg atIndex:index];
    }
}

// 将原始数据装箱为对象
+ (id)boxedValueWithBytes:(void *)bytes objCType:(const char *)objCType {
    if (strcmp(objCType, @encode(id)) == 0 || strcmp(objCType, @encode(Class)) == 0) {
        if (bytes) {
            id value;
            // 添加明确的 (void*) 类型转换来解决 ARC 所有权问题
            memcpy((void*)&value, (void *)bytes, sizeof(id));
            return value;
        }
        return nil;
    }
    else if (strcmp(objCType, @encode(BOOL)) == 0) {
        BOOL value = *(BOOL *)bytes;
        return @(value);
    }
    else if (strcmp(objCType, @encode(int)) == 0) {
        int value = *(int *)bytes;
        return @(value);
    }
    else if (strcmp(objCType, @encode(float)) == 0) {
        float value = *(float *)bytes;
        return @(value);
    }
    else if (strcmp(objCType, @encode(double)) == 0) {
        double value = *(double *)bytes;
        return @(value);
    }
    else if (strcmp(objCType, @encode(char *)) == 0) {
        const char *value = *(const char **)bytes;
        return value ? @(value) : nil;
    }
    
    // 对于不支持的类型，返回 nil
    return nil;
}

@end