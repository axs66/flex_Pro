#import "RTBObjectMonitor.h"
#import <objc/runtime.h>

@implementation RTBObjectMonitor

+ (void)startMonitoringObject:(id)object {
    if (!object) return;
    
    Class originalClass = object_getClass(object);
    NSString *originalClassName = NSStringFromClass(originalClass);
    NSString *newClassName = [NSString stringWithFormat:@"RTBMonitored_%@", originalClassName];
    
    // 防止重复监控
    if ([newClassName hasPrefix:@"RTBMonitored_"]) return;
    
    Class newClass = objc_allocateClassPair(originalClass, newClassName.UTF8String, 0);
    if (!newClass) return;
    
    // 将对象的isa指向新创建的类
    objc_registerClassPair(newClass);
    object_setClass(object, newClass);
    
    // 获取原类的所有方法并替换
    unsigned int methodCount;
    Method *methods = class_copyMethodList(originalClass, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        IMP implementation = method_getImplementation(method);
        const char *typeEncoding = method_getTypeEncoding(method);
        
        // 添加原始方法实现
        class_addMethod(newClass, selector, implementation, typeEncoding);
        
        // 如果不是系统方法，添加监控
        NSString *selectorName = NSStringFromSelector(selector);
        if (![selectorName hasPrefix:@"_"] && 
            ![selectorName hasPrefix:@"."] && 
            ![selectorName hasPrefix:@"dealloc"]) {
            
            // 添加监控方法
            SEL monitoredSelector = NSSelectorFromString([NSString stringWithFormat:@"rtb_%@", selectorName]);
            IMP monitoredIMP = [self createMonitoredImplementationForSelector:selector];
            class_addMethod(newClass, monitoredSelector, monitoredIMP, typeEncoding);
            
            // 替换原方法
            method_exchangeImplementations(
                class_getInstanceMethod(newClass, selector),
                class_getInstanceMethod(newClass, monitoredSelector)
            );
        }
    }
    free(methods);
}

+ (IMP)createMonitoredImplementationForSelector:(SEL)selector {
    // 创建监控方法...
    return nil;
}

+ (void)stopMonitoringObject:(id)object {
    if (!object) return;
    
    Class currentClass = object_getClass(object);
    NSString *currentClassName = NSStringFromClass(currentClass);
    
    // 检查是否正在监控（类名应该有前缀）
    if (![currentClassName hasPrefix:@"RTBMonitored_"]) {
        return;  // 对象没有被监控，不需要操作
    }
    
    // 提取原始类名
    NSString *originalClassName = [currentClassName substringFromIndex:12]; // "RTBMonitored_" 的长度
    Class originalClass = NSClassFromString(originalClassName);
    
    if (originalClass) {
        // 恢复对象原始类
        object_setClass(object, originalClass);
        NSLog(@"已停止监控对象 %@ (类: %@)", object, originalClassName);
    }
}

@end