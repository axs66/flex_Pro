#import "RuntimeBrowserFactory.h"
#import "RuntimeBrowserHeaders.h"
#import "RTBObjectsTVC+DoKitExtensions.h"
#import "RTBViewHierarchyVC+DoKitExtensions.h"
#import "RTBMemoryLeakDetector.h"
#import "RTBHookManager.h"
#import "FLEXHookDetector.h"
#import "RTBRuntime+DoKitEnhanced.h"
#import "RTBNetworkAnalyzerViewController.h"
#import "RTBPerformanceMonitorViewController.h"
#import "RTBMemoryAnalyzerViewController.h"
#import "RTBNetworkAnalyzer.h"
#import "RTBAdvancedRuntimeViewController.h"
#import "RTBFileBrowserController.h"
#import "RTBRuntimeController.h"
#import "RTBSearchToken.h"
#import "RTBRuntime+FLEXSafety.h"
#import "RTBHookDetectorViewController.h"


@implementation RuntimeBrowserFactory

+ (RTBTreeTVC *)createClassHierarchyBrowser {
    @try {
        // 确保Runtime已初始化
        [RTBRuntime ensureRuntimeInitialized];
        
        RTBTreeTVC *treeController = [[RTBTreeTVC alloc] initWithStyle:UITableViewStylePlain];
        treeController.title = @"类层次结构";
        
        RTBRuntime *runtime = [RTBRuntime sharedInstance];
        treeController.allClasses = runtime;
        
        return treeController;
    } @catch (NSException *exception) {
        NSLog(@"RuntimeBrowser: 创建类层次浏览器失败 - %@", exception.reason);
        return nil;
    }
}

+ (RTBClassDisplayVC *)createClassDisplayViewControllerForClass:(Class)cls {
    @try {
        RTBClassDisplayVC *vc = [[RTBClassDisplayVC alloc] init];
        vc.className = NSStringFromClass(cls);
        vc.title = NSStringFromClass(cls);
        return vc;
    } @catch (NSException *exception) {
        NSLog(@"RuntimeBrowser: 创建类显示控制器失败 - %@", exception.reason);
        return nil;
    }
}

+ (RTBObjectsTVC *)createObjectBrowserForObject:(id)object {
    @try {
        RTBObjectsTVC *vc = [[RTBObjectsTVC alloc] init];
        
        // 尝试多种方式设置对象
        if ([vc respondsToSelector:@selector(setInspectedObject:)]) {
            [vc performSelector:@selector(setInspectedObject:) withObject:object];
        } else if ([vc respondsToSelector:@selector(setObject:)]) {
            [vc performSelector:@selector(setObject:) withObject:object];
        } else {
            // 使用KVC设置
            @try {
                [vc setValue:object forKey:@"object"];
            } @catch (NSException *kvcException) {
                NSLog(@"RuntimeBrowser: 无法设置检查对象 - %@", kvcException.reason);
            }
        }
        
        vc.title = [NSString stringWithFormat:@"%@", [object class]];
        return vc;
    } @catch (NSException *exception) {
        NSLog(@"RuntimeBrowser: 创建对象浏览器失败 - %@", exception.reason);
        return nil;
    }
}

+ (RTBViewHierarchyVC *)createViewHierarchyBrowserWithTarget:(UIView *)targetView {
    @try {
        RTBViewHierarchyVC *vc = [[RTBViewHierarchyVC alloc] init];
        if ([vc respondsToSelector:@selector(setTargetView:)]) {
            vc.targetView = targetView;
        }
        return vc;
    } @catch (NSException *exception) {
        NSLog(@"RuntimeBrowser: 创建视图层次浏览器失败 - %@", exception.reason);
        return nil;
    }
}

+ (NSString *)generateHeaderForClass:(Class)cls {
    @try {
        if (!cls) return @"// 无效的类";
        
        // 使用RuntimeBrowser原生方法生成头文件
        BOOL displayPropertiesDefaultValues = [[NSUserDefaults standardUserDefaults] boolForKey:@"RTBDisplayPropertiesDefaultValues"];
        NSString *header = [RTBRuntimeHeader headerForClass:cls displayPropertiesDefaultValues:displayPropertiesDefaultValues];
        
        return header ?: @"// 无法生成头文件";
    } @catch (NSException *exception) {
        NSLog(@"RuntimeBrowser: 生成头文件失败 - %@", exception.reason);
        return [NSString stringWithFormat:@"// 生成头文件时发生错误: %@", exception.reason];
    }
}

+ (BOOL)saveHeaderForClass:(Class)cls toPath:(NSString *)path {
    @try {
        NSString *header = [self generateHeaderForClass:cls];
        if (header && header.length > 0) {
            NSError *error;
            BOOL success = [header writeToFile:path 
                                   atomically:YES 
                                     encoding:NSUTF8StringEncoding 
                                        error:&error];
            if (!success) {
                NSLog(@"RuntimeBrowser: 保存头文件失败 - %@", error.localizedDescription);
            }
            return success;
        }
        return NO;
    } @catch (NSException *exception) {
        NSLog(@"RuntimeBrowser: 保存头文件异常 - %@", exception.reason);
        return NO;
    }
}

// 在现有实现基础上添加DoKit功能

+ (RTBObjectsTVC *)createAdvancedObjectBrowserForObject:(id)object {
    RTBObjectsTVC *vc = [self createObjectBrowserForObject:object];
    
    // 增强对象浏览器功能
    if (vc) {
        // 添加DoKit分析功能
        vc.enabledDoKitAnalysis = YES;
        
        // 检查内存泄漏
        BOOL hasLeak = [[RTBMemoryLeakDetector sharedInstance] checkObjectForLeak:object];
        if (hasLeak) {
            vc.memoryLeakDetected = YES;
        }
        
        // 添加网络监控（如果对象是网络相关的）
        if ([object isKindOfClass:[NSURLRequest class]] || 
            [object isKindOfClass:[NSURLResponse class]]) {
            vc.networkMonitoringEnabled = YES;
        }
    }
    
    return vc;
}

+ (RTBViewHierarchyVC *)createAdvancedViewHierarchyBrowser:(UIView *)targetView {
    RTBViewHierarchyVC *vc = [self createViewHierarchyBrowserWithTarget:targetView];
    
    if (vc) {
        // 添加DoKit视图分析功能
        RTBViewNode *hierarchyAnalysis = [[RTBViewHierarchyAnalyzer sharedInstance] analyzeViewHierarchy:targetView];
        vc.hierarchyAnalysis = hierarchyAnalysis;
        
        // 性能问题检测
        NSArray *performanceIssues = [[RTBViewHierarchyAnalyzer sharedInstance] detectPerformanceIssues:targetView];
        vc.performanceIssues = performanceIssues;
    }
    
    return vc;
}

+ (NSDictionary *)generateAdvancedClassAnalysis:(Class)cls {
    NSMutableDictionary *analysis = [NSMutableDictionary dictionary];
    
    // 基础类信息
    analysis[@"className"] = NSStringFromClass(cls);
    analysis[@"superClass"] = NSStringFromClass([cls superclass]);
    
    // 使用DoKit的Hook管理器分析
    NSArray *hookedMethods = [[RTBHookManager sharedInstance] getAllHookedMethods];
    NSPredicate *classFilter = [NSPredicate predicateWithFormat:@"class == %@", NSStringFromClass(cls)];
    analysis[@"hookedMethods"] = [hookedMethods filteredArrayUsingPredicate:classFilter];
    
    // 性能相关分析
    if ([cls isSubclassOfClass:[UIViewController class]]) {
        analysis[@"isViewController"] = @YES;
        // 可以添加更多视图控制器特定的分析
    }
    
    if ([cls isSubclassOfClass:[UIView class]]) {
        analysis[@"isView"] = @YES;
        // 可以添加更多视图特定的分析
    }
    
    return analysis;
}

#pragma mark - DoKit增强功能

+ (UIViewController *)createHookDetectorViewController {
    RTBHookDetectorViewController *vc = [[RTBHookDetectorViewController alloc] init];
    vc.title = @"Hook检测器";
    return vc;
}

+ (UIViewController *)createNetworkAnalyzerViewController {
    RTBNetworkAnalyzerViewController *vc = [[RTBNetworkAnalyzerViewController alloc] init];
    vc.title = @"网络分析器";
    return vc;
}

+ (UIViewController *)createPerformanceMonitorViewController {
    RTBPerformanceMonitorViewController *vc = [[RTBPerformanceMonitorViewController alloc] init];
    vc.title = @"性能监控";
    return vc;
}

+ (UIViewController *)createMemoryAnalyzerViewController {
    RTBMemoryAnalyzerViewController *vc = [[RTBMemoryAnalyzerViewController alloc] init];
    vc.title = @"内存分析";
    return vc;
}

+ (NSArray *)getEnhancedClassInfo:(Class)cls {
    RTBRuntime *runtime = [RTBRuntime sharedInstance];
    
    NSMutableDictionary *enhancedInfo = [NSMutableDictionary dictionary];
    
    // 基础信息
    enhancedInfo[@"className"] = NSStringFromClass(cls);
    enhancedInfo[@"superclass"] = NSStringFromClass(class_getSuperclass(cls));
    enhancedInfo[@"instanceSize"] = @(class_getInstanceSize(cls));
    
    // 使用安全的方法调用
    if ([runtime respondsToSelector:@selector(dokit_getMethodsForClass:includeHooked:)]) {
        enhancedInfo[@"methods"] = [runtime dokit_getMethodsForClass:cls includeHooked:YES];
    } else {
        enhancedInfo[@"methods"] = @[];
    }
    
    // 将 RTBHookDetector 修改为 FLEXHookDetector
    if ([FLEXHookDetector class]) {
        enhancedInfo[@"hookedMethods"] = [[FLEXHookDetector sharedDetector] getHookedMethodsForClass:cls];
    } else {
        enhancedInfo[@"hookedMethods"] = @[];
    }
    
    if ([runtime respondsToSelector:@selector(dokit_getAllInstancesOfClass:)]) {
        enhancedInfo[@"instances"] = [runtime dokit_getAllInstancesOfClass:cls];
    } else {
        enhancedInfo[@"instances"] = @[];
    }
    
    if ([runtime respondsToSelector:@selector(dokit_getInstanceCountForClass:)]) {
        enhancedInfo[@"instanceCount"] = @([runtime dokit_getInstanceCountForClass:cls]);
    } else {
        enhancedInfo[@"instanceCount"] = @(0);
    }
    
    return @[enhancedInfo];
}

+ (NSDictionary *)getSystemAnalysis {
    NSMutableDictionary *analysis = [NSMutableDictionary dictionary];
    
    // 运行时信息
    RTBRuntime *runtime = [RTBRuntime sharedInstance];
    analysis[@"classHierarchyTree"] = [runtime dokit_getClassHierarchyTree];
    analysis[@"totalClasses"] = @([runtime dokit_getAllClassesWithPrefix:nil].count);
    
    // Hook信息 - 将 RTBHookDetector 修改为 FLEXHookDetector
    FLEXHookDetector *hookDetector = [FLEXHookDetector sharedDetector];
    analysis[@"hookedMethods"] = [hookDetector getAllHookedMethods];
    analysis[@"swizzledMethods"] = [hookDetector getAllSwizzledMethods];
    
    // 网络信息
    RTBNetworkAnalyzer *networkAnalyzer = [RTBNetworkAnalyzer sharedAnalyzer];
    analysis[@"networkStatistics"] = [networkAnalyzer getNetworkStatistics];
    analysis[@"recentRequests"] = [networkAnalyzer getAllRequests];
    
    return analysis;
}

#pragma mark - FLEX增强功能

+ (UIViewController *)createAdvancedRuntimeBrowser {
    RTBAdvancedRuntimeViewController *vc = [[RTBAdvancedRuntimeViewController alloc] init];
    vc.title = @"高级运行时浏览器";
    return vc;
}

+ (UIViewController *)createMemoryAnalyzer {
    RTBMemoryAnalyzerViewController *vc = [[RTBMemoryAnalyzerViewController alloc] init];
    vc.title = @"内存分析器";
    return vc;
}

+ (UIViewController *)createFileBrowserWithPath:(NSString *)path {
    return [RTBFileBrowserController withPath:path];
}

+ (UIViewController *)createBundleBrowser {
    return [self createFileBrowserWithPath:NSBundle.mainBundle.bundlePath];
}

+ (UIViewController *)createDocumentsBrowser {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = paths.firstObject;
    return [self createFileBrowserWithPath:documentsPath];
}

+ (NSDictionary *)getAdvancedSystemAnalysis {
    RTBRuntimeController *controller = [RTBRuntimeController sharedController];
    RTBRuntime *runtime = [RTBRuntime sharedInstance];
    
    return @{
        // 运行时统计
        @"runtime": @{
            @"totalBundles": @([controller allBundleNames].count),
            @"totalClasses": @([controller classesForToken:[RTBSearchToken any] inBundles:nil].count),
            @"bundleNames": [controller allBundleNames]
        },
        
        // 内存统计
        @"memory": [runtime flex_getHeapSnapshot],
        
        // 系统信息
        @"system": @{
            @"bundlePath": NSBundle.mainBundle.bundlePath,
            @"documentsPath": NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject,
            @"libraryPath": NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject
        }
    };
}

+ (NSArray *)searchClassesWithPattern:(NSString *)pattern {
    RTBRuntimeController *controller = [RTBRuntimeController sharedController];
    RTBSearchToken *token = [RTBSearchToken tokenWithString:pattern options:0];
    return [controller classesForToken:token inBundles:nil];
}

+ (NSArray *)getInstancesOfClass:(Class)cls {
    RTBRuntimeController *controller = [RTBRuntimeController sharedController];
    return [controller getAllInstancesOfClass:cls];
}

+ (NSDictionary *)getDetailedClassInfo:(Class)cls {
    RTBRuntimeController *controller = [RTBRuntimeController sharedController];
    
    return @{
        @"className": NSStringFromClass(cls),
        @"bundleName": [controller shortBundleNameForClass:NSStringFromClass(cls)],
        @"hierarchy": [controller getClassHierarchyForClass:cls],
        @"subclasses": [controller getSubclassesForClass:cls],
        @"methods": [controller getMethodsForClass:cls includePrivate:YES],
        @"properties": [controller getPropertiesForClass:cls includePrivate:YES],
        @"protocols": [controller getProtocolsForClass:cls],
        @"ivars": [controller getIvarsForClass:cls],
        @"instances": @([controller getInstanceCountForClass:cls])
    };
}

#pragma mark - Method Profiler

+ (void)startMethodProfiler {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"[DYYYRuntimeBrowserFactory] 启动方法分析器");
    });
    
    // 获取所有类并启动监控
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    
    for (unsigned int i = 0; i < count; i++) {
        Class cls = classes[i];
        // 仅监控应用内的类，避免系统类
        NSString *className = NSStringFromClass(cls);
        if ([className hasPrefix:@"UI"] || [className hasPrefix:@"NS"]) {
            continue;
        }
        
        [self startProfilingClass:cls];
    }
    
    free(classes);
}

+ (void)stopMethodProfiler {
    NSLog(@"[DYYYRuntimeBrowserFactory] 停止方法分析器");
    
    // 获取所有类并停止监控
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    
    for (unsigned int i = 0; i < count; i++) {
        Class cls = classes[i];
        NSString *className = NSStringFromClass(cls);
        if ([className hasPrefix:@"UI"] || [className hasPrefix:@"NS"]) {
            continue;
        }
        
        [self stopProfilingClass:cls];
    }
    
    free(classes);
}

+ (NSArray *)getProfiledMethodResults {
    NSMutableArray *results = [NSMutableArray array];
    
    // 从静态存储中获取收集的数据
    NSDictionary *profileData = [self getProfileData];
    
    // 将数据转换为结果数组
    for (NSString *className in profileData) {
        NSDictionary *classMethods = profileData[className];
        
        for (NSString *methodName in classMethods) {
            NSDictionary *methodData = classMethods[methodName];
            
            [results addObject:@{
                @"className": className,
                @"methodName": methodName,
                @"callCount": methodData[@"callCount"] ?: @0,
                @"totalTime": methodData[@"totalTime"] ?: @0.0,
                @"averageTime": methodData[@"averageTime"] ?: @0.0
            }];
        }
    }
    
    // 按平均执行时间排序
    [results sortUsingDescriptors:@[
        [NSSortDescriptor sortDescriptorWithKey:@"averageTime" ascending:NO]
    ]];
    
    return results;
}

#pragma mark - Helper Methods

// 保存分析数据的静态字典
+ (NSMutableDictionary *)getProfileData {
    static NSMutableDictionary *profileData = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        profileData = [NSMutableDictionary dictionary];
    });
    
    return profileData;
}

+ (void)startProfilingClass:(Class)cls {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        NSString *methodName = NSStringFromSelector(selector);
        
        // 创建跟踪实现
        IMP newImp = imp_implementationWithBlock(^id(id self, ...) {
            // 开始时间
            NSDate *startTime = [NSDate date];
            
            // 调用原始方法
            id result = nil;
            NSMethodSignature *signature = [cls instanceMethodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            invocation.selector = selector;
            invocation.target = self;
            [invocation invoke];
            
            // 如果有返回值，获取它
            if (signature.methodReturnLength) {
                [invocation getReturnValue:&result];
            }
            
            // 计算耗时
            NSTimeInterval elapsedTime = [[NSDate date] timeIntervalSinceDate:startTime];
            
            // 记录方法调用数据
            NSString *className = NSStringFromClass(cls);
            NSMutableDictionary *profileData = [self getProfileData];
            
            if (!profileData[className]) {
                profileData[className] = [NSMutableDictionary dictionary];
            }
            
            if (!profileData[className][methodName]) {
                profileData[className][methodName] = [@{
                    @"callCount": @0,
                    @"totalTime": @0.0,
                    @"averageTime": @0.0
                } mutableCopy];
            }
            
            NSMutableDictionary *methodData = profileData[className][methodName];
            NSInteger callCount = [methodData[@"callCount"] integerValue] + 1;
            NSTimeInterval totalTime = [methodData[@"totalTime"] doubleValue] + elapsedTime;
            NSTimeInterval averageTime = totalTime / callCount;
            
            methodData[@"callCount"] = @(callCount);
            methodData[@"totalTime"] = @(totalTime);
            methodData[@"averageTime"] = @(averageTime);
            
            return result;
        });
        
        // 保存原始实现和方法
        method_setImplementation(method, newImp);
    }
    
    if (methods) {
        free(methods);
    }
}

+ (void)stopProfilingClass:(Class)cls {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    // 如果需要，可以在这里恢复原始方法实现
    // 但是根据现有代码，我们只是记录了数据，没有保存原始实现
    // 所以这里暂时不做任何操作
    
    if (methods) {
        free(methods);
    }
}
@end