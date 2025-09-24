#import "UIViewController+DoraemonUIProfile.h"
#import <objc/runtime.h>

@implementation UIViewController (DoraemonUIProfile)

+ (void)startDoraemonUIProfileMonitoring {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 在这里实现方法交换逻辑
        [self swizzleViewDidAppear];
        [self swizzleViewWillDisappear];
    });
    
    NSLog(@"Doraemon UI性能监控已启动");
}

+ (void)stopDoraemonUIProfileMonitoring {
    NSLog(@"Doraemon UI性能监控已停止");
    // 在真实实现中，这里可能需要恢复原始方法
}

+ (void)swizzleViewDidAppear {
    Class class = [self class];
    
    SEL originalSelector = @selector(viewDidAppear:);
    SEL swizzledSelector = @selector(doraemon_viewDidAppear:);
    
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    
    BOOL didAddMethod = class_addMethod(class,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(class,
                           swizzledSelector,
                           method_getImplementation(originalMethod),
                           method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

+ (void)swizzleViewWillDisappear {
    // 类似的实现方法交换逻辑
}

- (void)doraemon_viewDidAppear:(BOOL)animated {
    // 调用原始实现
    [self doraemon_viewDidAppear:animated];
    
    // 添加性能分析代码
    [self doraemon_profileViewDidAppear];
}

- (void)doraemon_profileViewDidAppear {
    // 记录视图出现时间
    NSLog(@"视图出现性能分析: %@", NSStringFromClass([self class]));
}

- (void)doraemon_profileViewWillDisappear {
    // 记录视图消失时间
    NSLog(@"视图消失性能分析: %@", NSStringFromClass([self class]));
}

@end