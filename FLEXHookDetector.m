//
//  FLEXHookDetector.m
//  FLEX
//
//  Created from RuntimeBrowser functionalities.
//

#import "FLEXHookDetector.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>

@implementation FLEXHookDetector

+ (instancetype)sharedDetector {
    static FLEXHookDetector *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (BOOL)isMethodHooked:(Method)method ofClass:(Class)cls {
    if (!method || !cls) return NO;
    
    SEL selector = method_getName(method);
    IMP imp = class_getMethodImplementation(cls, selector);
    IMP originalImp = method_getImplementation(method);
    
    // 从 RTBHookDetector 移植的检测逻辑
    
    // 检查 IMP 地址是否在可执行段外
    Dl_info info;
    if (dladdr((void *)imp, &info)) {
        // 如果 IMP 不在原始库中，可能被 hook
        if (strstr(info.dli_fname, "hook") || strstr(info.dli_fname, "substrate")) {
            return YES;
        }
    }
    
    // 检查方法实现是否被替换
    return (imp != originalImp);
}

- (NSArray *)getHookedMethodsForClass:(Class)cls {
    if (!cls) return @[];
    
    NSMutableArray *hookedMethods = [NSMutableArray array];
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        if ([self isMethodHooked:method ofClass:cls]) {
            SEL selector = method_getName(method);
            IMP imp = class_getMethodImplementation(cls, selector);
            IMP originalImp = method_getImplementation(method);
            
            // 从 RTB 移植的详细信息收集
            Dl_info hookInfo;
            NSString *hookLocation = @"Unknown";
            if (dladdr((void *)imp, &hookInfo) && hookInfo.dli_fname) {
                hookLocation = @(hookInfo.dli_fname);
            }
            
            [hookedMethods addObject:@{
                @"selector": NSStringFromSelector(selector),
                @"currentAddress": [NSString stringWithFormat:@"%p", imp],
                @"originalAddress": [NSString stringWithFormat:@"%p", originalImp],
                @"hookLocation": hookLocation,
                @"typeEncoding": @(method_getTypeEncoding(method) ?: "")
            }];
        }
    }
    
    free(methods);
    return hookedMethods;
}

// 修改 getAllHookedMethods 方法

// 确保方法返回类型正确，并且实现也返回正确的类型
- (NSDictionary *)getAllHookedMethods {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        NSArray *hookedMethods = [self getHookedMethodsForClass:cls];
        
        if (hookedMethods.count > 0) {
            result[NSStringFromClass(cls)] = hookedMethods;
        }
    }
    
    free(classes);
    return result;
}

// getDetailedHookAnalysis 方法也需要保持一致
- (NSDictionary *)getDetailedHookAnalysis {
    NSMutableDictionary *analysis = [NSMutableDictionary dictionary];
    
    // 获取 hook 方法按类分组的字典
    NSDictionary *hookedMethodsByClass = [self getAllHookedMethods];
    
    // 转换为符合预期的数据格式
    NSMutableArray *hookedClassesArray = [NSMutableArray array];
    
    for (NSString *className in hookedMethodsByClass) {
        NSArray *methods = hookedMethodsByClass[className];
        [hookedClassesArray addObject:@{
            @"className": className,
            @"hookedMethodsCount": @(methods.count),
            @"methods": methods
        }];
    }
    
    // 添加统计信息
    analysis[@"totalHookedClasses"] = @(hookedClassesArray.count);
    analysis[@"hookedClasses"] = hookedClassesArray;
    
    // 计算总的被hook方法数
    NSUInteger totalMethods = 0;
    for (NSArray *methods in hookedMethodsByClass.allValues) {
        totalMethods += methods.count;
    }
    analysis[@"totalHookedMethods"] = @(totalMethods);
    
    return analysis;
}

// 实现缺失的 getAllSwizzledMethods 方法
- (NSArray *)getAllSwizzledMethods {
    NSMutableArray *allSwizzledMethods = [NSMutableArray array];
    
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        NSArray *swizzled = [self getSwizzledMethodsForClass:cls];
        
        if (swizzled.count > 0) {
            [allSwizzledMethods addObject:@{
                @"class": NSStringFromClass(cls),
                @"methods": swizzled
            }];
        }
    }
    
    free(classes);
    return allSwizzledMethods;
}

// 添加必要的辅助方法
- (NSArray *)getSwizzledMethodsForClass:(Class)cls {
    NSMutableArray *swizzled = [NSMutableArray array];
    
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        
        if ([self isMethodSwizzled:selector inClass:cls]) {
            [swizzled addObject:@{
                @"selector": NSStringFromSelector(selector),
                @"originalIMP": [NSString stringWithFormat:@"%p", method_getImplementation(method)]
            }];
        }
    }
    
    free(methods);
    return swizzled;
}

- (BOOL)isMethodSwizzled:(SEL)selector inClass:(Class)cls {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return NO;
    
    IMP imp = method_getImplementation(method);
    IMP classImp = class_getMethodImplementation(cls, selector);
    
    // 检查实现是否被替换
    return imp != classImp;
}

@end