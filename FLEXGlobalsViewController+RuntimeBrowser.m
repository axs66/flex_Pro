#import <objc/runtime.h>
#import "FLEXGlobalsViewController+RuntimeBrowser.h"
#import "FLEXManager+RuntimeBrowser.h"
#import "FLEXRuntimeClient+RuntimeBrowser.h"
#import "FLEXRuntimeClient.h"

@implementation FLEXGlobalsViewController (RuntimeBrowser)

- (void)addRuntimeBrowserEntries {
    // 直接使用FLEXManager的方法来注册，避免重复
    [[FLEXManager sharedManager] registerRuntimeBrowserTools];
    
    // 刷新表格视图以显示新添加的条目
    if ([self respondsToSelector:@selector(reloadData)]) {
        [self performSelector:@selector(reloadData)];
    }
}

// 将其他方法转发给FLEXRuntimeClient
- (NSArray *)sortedClassStubs {
    return [[FLEXRuntimeClient runtime] sortedClassStubs];
}

- (void)emptyCachesAndReadAllRuntimeClasses {
    [[FLEXRuntimeClient runtime] emptyCachesAndReadAllRuntimeClasses];
}

- (NSDictionary *)getDetailedClassInfo:(Class)cls {
    return [[FLEXRuntimeClient runtime] getDetailedClassInfo:cls];
}

- (NSString *)generateHeaderForClass:(Class)cls {
    return [[FLEXRuntimeClient runtime] generateHeaderForClass:cls];
}

// 实现FLEXHookDetector的空方法
- (BOOL)rtb_isMethodSwizzled:(SEL)selector inClass:(Class)cls {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return NO;
    
    IMP imp = method_getImplementation(method);
    IMP classImp = class_getMethodImplementation(cls, selector);
    
    return imp != classImp;
}

@end