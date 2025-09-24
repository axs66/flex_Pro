//
//  FLEXManager+DoKitExtensions.m
//  FLEX
//
//

#import "FLEXManager+DoKitExtensions.h"
#import "FLEXManager+Extensibility.h"
#import "FLEXBugViewController.h"
#import "FLEXDoKitManager.h"
#import "FLEXDoKitPerformanceMonitor.h"
#import "FLEXDoKitNetworkMonitor.h"
#import "FLEXDoKitVisualTools.h"

#import "FLEXDoKitCPUViewController.h"
#import "FLEXMemoryMonitorViewController.h"
#import "FLEXDoKitLagViewController.h"
#import "FLEXDoKitNetworkViewController.h"
#import "FLEXDoKitMockViewController.h"
#import "FLEXDoKitWeakNetworkViewController.h"
#import "FLEXDoKitColorPickerViewController.h"
#import "FLEXDoKitVisualToolsViewController.h"
#import "FLEXRevealInspectorViewController.h"
#import "FLEXDoKitFileBrowserViewController.h"
#import "FLEXDoKitDatabaseViewController.h"
#import "FLEXDoKitUserDefaultsViewController.h"
#import "FLEXDoKitLogViewController.h"
#import "FLEXDoKitCrashViewController.h"
#import "FLEXDoKitCrashMonitor.h"
#import "FLEXDoKitMemoryLeakDetector.h"
#import "FLEXMemoryLeakDetectorViewController.h" 
#import "FLEXLookinMeasureController.h"
#import "FLEXLookinPreviewController.h"
#import "FLEXLookinHierarchyViewController.h"

@implementation FLEXManager (DoKitExtensions)

- (void)registerDoKitEnhancements {
    [self registerPerformanceMonitoring];
    [self registerNetworkDebugging];
    [self registerUIDebugging];
    [self registerMemoryDebugging];
    [self registerAdvancedDebugging];
    [self registerLookinEnhancements];
    [self registerCommonTools];
    
    NSLog(@"DoKit + Lookin 完整功能已注册完成");
}

// 实现缺失的 registerCommonTools 方法
- (void)registerCommonTools {
    // 注册通用工具
    [self registerGlobalEntryWithName:@"通用工具集"
                   objectFutureBlock:^id{
                       return [UIViewController new]; // 临时返回一个空的视图控制器，根据实际需求替换
                   }];
}

- (void)registerPerformanceMonitoring {
    // CPU监控
    [self registerGlobalEntryWithName:@"CPU使用率监控"
                   objectFutureBlock:^id{
                       // ✅ respondsToSelector检查
                       if ([[FLEXDoKitPerformanceMonitor sharedInstance] respondsToSelector:@selector(startCPUMonitoring)]) {
                           [[FLEXDoKitPerformanceMonitor sharedInstance] startCPUMonitoring];
                       } else {
                           NSLog(@"⚠️ 警告：FLEXDoKitPerformanceMonitor 不支持 startCPUMonitoring 方法");
                       }
                       return [FLEXDoKitCPUViewController new];
                   }];
    
    // 内存监控
    [self registerGlobalEntryWithName:@"内存使用监控"
                   objectFutureBlock:^id{
                       return [FLEXMemoryMonitorViewController new];
                   }];
    
    // 卡顿检测
    [self registerGlobalEntryWithName:@"卡顿检测"
                   objectFutureBlock:^id{
                       if ([[FLEXDoKitPerformanceMonitor sharedInstance] respondsToSelector:@selector(startLagDetection)]) {
                           [[FLEXDoKitPerformanceMonitor sharedInstance] startLagDetection];
                       } else {
                           NSLog(@"⚠️ 警告：FLEXDoKitPerformanceMonitor 不支持 startLagDetection 方法");
                       }
                       return [FLEXDoKitLagViewController new];
                   }];
}

- (void)registerNetworkDebugging {
    // 网络监控
    [self registerGlobalEntryWithName:@"网络请求监控"
                   objectFutureBlock:^id{
                       // 修复方法名
                       [[FLEXDoKitNetworkMonitor sharedInstance] startMonitoring];
                       return [FLEXDoKitNetworkViewController new];
                   }];
    
    // Mock数据
    [self registerGlobalEntryWithName:@"Mock数据管理"
                   objectFutureBlock:^id{
                       return [FLEXDoKitMockViewController new];
                   }];
    
    // 弱网模拟
    [self registerGlobalEntryWithName:@"弱网环境模拟"
                   objectFutureBlock:^id{
                       return [FLEXDoKitWeakNetworkViewController new];
                   }];
}

- (void)registerUIDebugging {
    // 颜色吸管
    [self registerGlobalEntryWithName:@"颜色拾取器"
                   objectFutureBlock:^id{
                       return [FLEXDoKitColorPickerViewController new];
                   }];
    
    // 视觉工具箱
    [self registerGlobalEntryWithName:@"视觉工具箱"
                   objectFutureBlock:^id{
                       return [FLEXDoKitVisualToolsViewController new];
                   }];
    
    // Reveal集成
    [self registerGlobalEntryWithName:@"视图层级检查器"
                   objectFutureBlock:^id{
                       return [FLEXRevealInspectorViewController new];
                   }];
}

- (void)registerMemoryDebugging {
    // 文件浏览器
    [self registerGlobalEntryWithName:@"文件系统浏览器"
                   objectFutureBlock:^id{
                       return [FLEXDoKitFileBrowserViewController new];
                   }];
    
    // 数据库浏览
    [self registerGlobalEntryWithName:@"数据库浏览器"
                   objectFutureBlock:^id{
                       return [FLEXDoKitDatabaseViewController new];
                   }];
    
    // UserDefaults
    [self registerGlobalEntryWithName:@"UserDefaults浏览器"
                   objectFutureBlock:^id{
                       return [FLEXDoKitUserDefaultsViewController new];
                   }];
}

- (void)registerAdvancedDebugging {
    [self registerGlobalEntryWithName:@"Dobby Hook 管理器" viewControllerFutureBlock:^UIViewController *{
        return [[FLEXDoKitViewController alloc] init];
    }];
    
    // 其他高级调试选项
    [self registerGlobalEntryWithName:@"运行时浏览器" viewControllerFutureBlock:^UIViewController *{
        return [[FLEXDoKitFileBrowserViewController alloc] init];
    }];
    
    // 日志查看器
    [self registerGlobalEntryWithName:@"日志查看器"
                   objectFutureBlock:^id{
                       return [FLEXDoKitLogViewController new];
                   }];
    
    // 崩溃记录
    [self registerGlobalEntryWithName:@"崩溃记录"
                   objectFutureBlock:^id{
                       return [FLEXDoKitCrashViewController new];
                   }];
    
    // 内存泄漏检测
    [self registerGlobalEntryWithName:@"内存泄漏检测"
                   objectFutureBlock:^id{
                       return [FLEXMemoryLeakDetectorViewController new];
                   }];
}

- (void)registerLookinEnhancements {
    // Lookin增强功能
    [self registerGlobalEntryWithName:@"Lookin视图层级"
                   objectFutureBlock:^id{
                       return [FLEXLookinHierarchyViewController new];
                   }];
}

@end