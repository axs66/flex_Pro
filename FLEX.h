//
//  FLEX.h
//  FLEX
//
//  Created by Eric Horacek on 7/18/15.
//  Modified by Tanner Bennett on 3/12/20.
//  Copyright (c) 2025 for pxx917144686 FLEX Team. All rights reserved.
//

// === 核心架构 ===
#import "FLEXManager.h"
#import "FLEXManager+Extensibility.h"
#import "FLEXManager+Networking.h"
#import "FLEXManager+DoKitExtensions.h"
#import "FLEXCompatibility.h"

#import "FLEXExplorerToolbar.h"
#import "FLEXExplorerToolbarItem.h"
#import "FLEXGlobalsEntry.h"

#import "FLEX-Core.h"
#import "FLEX-Runtime.h"
#import "FLEX-Categories.h"
#import "FLEX-ObjectExploring.h"
#import "FLEX-DoKit.h"

#import "FLEXMacros.h"
#import "FLEXAlert.h"
#import "FLEXResources.h"

#import "FLEXDoKitManager.h"
#import "FLEXDoKitPerformanceMonitor.h"
#import "FLEXDoKitNetworkMonitor.h"
#import "FLEXDoKitVisualTools.h"
#import "FLEXDoKitCrashMonitor.h"
#import "FLEXDoKitLogViewer.h"
#import "FLEXDoKitLogEntry.h"
#import "FLEXDoKitMemoryLeakDetector.h"

// === 主控制器 ===
#import "FLEXBugViewController.h"

// === 性能监控 ===
#import "FLEXPerformanceViewController.h"
#import "FLEXMemoryMonitorViewController.h"
#import "FLEXFPSMonitorViewController.h"
#import "FLEXDoKitCPUViewController.h"
#import "FLEXDoKitLagViewController.h"
#import "FLEXMemoryLeakDetectorViewController.h"
#import "FLEXDoKitCrashViewController.h"

// === 网络工具 ===
#import "FLEXNetworkMonitorViewController.h"
#import "FLEXAPITestViewController.h"
#import "FLEXDoKitMockViewController.h"
#import "FLEXDoKitNetworkViewController.h"
#import "FLEXDoKitNetworkHistoryViewController.h"
#import "FLEXDoKitWeakNetworkViewController.h"
#import "FLEXNetworkMITMViewController.h"

// === 视觉工具 ===
#import "FLEXDoKitColorPickerViewController.h"
#import "FLEXDoKitComponentViewController.h"
#import "FLEXDoKitVisualToolsViewController.h" 

// === 日志工具 ===
#import "FLEXDoKitLogViewController.h"
#import "FLEXDoKitLogFilterViewController.h"

// === 常用工具 ===
#import "FLEXDoKitAppInfoViewController.h"
#import "FLEXDoKitSystemInfoViewController.h"
#import "FLEXDoKitCleanViewController.h"
#import "FLEXDoKitUserDefaultsViewController.h"
#import "FLEXFileBrowserController.h"
#import "FLEXDoKitFileBrowserViewController.h"
#import "FLEXDoKitH5ViewController.h"
#import "FLEXDoKitDatabaseViewController.h"

#import "FLEXRevealLikeInspector.h"
#import "FLEXRevealInspectorViewController.h"

#import "FLEXLookinInspector.h"
#import "FLEXLookinHierarchyViewController.h"
#import "FLEXLookinComparisonViewController.h"
#import "FLEXLookinMeasureController.h"
#import "FLEXLookinMeasureResultView.h"
#import "FLEXLookinDisplayItem.h"
#import "FLEXLookinPreviewController.h"
#import "FLEXLookinMeasureViewController.h"

// === 运行时分析 ===
// 主入口文件
#import "FLEXRuntimeBrowser.h"
// 核心组件
#import "FLEXRuntimeBrowserViewController.h"
#import "FLEXRuntimeClient.h"
#import "FLEXRuntimeClient+RuntimeBrowser.h"
#import "FLEXClassHierarchyViewController.h"
#import "FLEXClassPerformanceViewController.h"
// 扩展组件
#import "FLEXManager+RuntimeBrowser.h"
#import "FLEXHookDetector.h"
#import "FLEXHookDetector+RuntimeBrowser.h"
#import "FLEXGlobalsViewController+RuntimeBrowser.h"
#import "FLEXSystemAnalyzerViewController+RuntimeBrowser.h"
#import "FLEXMemoryAnalyzer+RuntimeBrowser.h"
#import "FLEXFileBrowserController+RuntimeBrowser.h"

// === 错误修复工具 ===
#import "FLEXSystemLogViewController.h"
#import "FLEXHierarchyTableViewController.h"

// === 系统分析 ===
#import "FLEXSystemAnalyzerViewController.h"

// FLEX + DoKit 核心管理器宏
#define FLEXProManager [FLEXManager sharedManager]

// DoKit特定功能启用
#define FLEXEnableDoKit() [[FLEXManager sharedManager] setDoKitEnabled:YES]

// 网络监控相关
#define FLEXStartNetworkMonitoring() [[[FLEXManager sharedManager] networkMonitor] startMonitoring]
#define FLEXStopNetworkMonitoring() [[[FLEXManager sharedManager] networkMonitor] stopMonitoring]

// 日志记录相关
#define FLEXLogErrorDoKit(tag, format, ...) FLEXLogError(tag, format, ##__VA_ARGS__)
#define FLEXLogWarningDoKit(tag, format, ...) FLEXLogWarning(tag, format, ##__VA_ARGS__)
#define FLEXLogInfoDoKit(tag, format, ...) FLEXLogInfo(tag, format, ##__VA_ARGS__)
#define FLEXLogDebugDoKit(tag, format, ...) FLEXLogDebug(tag, format, ##__VA_ARGS__)

// 快速访问视图控制器
#define FLEXShowNetworkVC() \
    do { \
        UIViewController *vc = [[FLEXDoKitNetworkViewController alloc] init]; \
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc]; \
        nav.modalPresentationStyle = UIModalPresentationFullScreen; \
        [[[UIApplication sharedApplication] keyWindow].rootViewController presentViewController:nav animated:YES completion:nil]; \
    } while(0)

#define FLEXShowFileBrowserVC() \
    do { \
        UIViewController *vc = [[FLEXDoKitFileBrowserViewController alloc] init]; \
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc]; \
        nav.modalPresentationStyle = UIModalPresentationFullScreen; \
        [[[UIApplication sharedApplication] keyWindow].rootViewController presentViewController:nav animated:YES completion:nil]; \
    } while(0)

#define FLEXShowDatabaseVC() \
    do { \
        UIViewController *vc = [[FLEXDoKitDatabaseViewController alloc] init]; \
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc]; \
        nav.modalPresentationStyle = UIModalPresentationFullScreen; \
        [[[UIApplication sharedApplication] keyWindow].rootViewController presentViewController:nav animated:YES completion:nil]; \
    } while(0)

#define FLEXShowCrashVC() \
    do { \
        UIViewController *vc = [[FLEXDoKitCrashViewController alloc] init]; \
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc]; \
        nav.modalPresentationStyle = UIModalPresentationFullScreen; \
        [[[UIApplication sharedApplication] keyWindow].rootViewController presentViewController:nav animated:YES completion:nil]; \
    } while(0)

#define FLEXShowCleanVC() \
    do { \
        UIViewController *vc = [[FLEXDoKitCleanViewController alloc] init]; \
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc]; \
        nav.modalPresentationStyle = UIModalPresentationFullScreen; \
        [[[UIApplication sharedApplication] keyWindow].rootViewController presentViewController:nav animated:YES completion:nil]; \
    } while(0)

// 启用FLEX+DoKit完整功能
#define FLEXEnableProKit() \
do { \
    [[FLEXManager sharedManager] showExplorerFromScene:nil]; \
    FLEXDoKitEnable(); \
} while(0)
