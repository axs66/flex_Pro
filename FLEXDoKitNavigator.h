#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// DoKit的悬浮窗导航器，提供快速访问各功能模块的悬浮按钮
@interface FLEXDoKitNavigator : NSObject

/// 共享实例
+ (instancetype)sharedNavigator;

/// 显示悬浮按钮
- (void)show;

/// 隐藏悬浮按钮
- (void)hide;

/// 显示工具按钮
- (void)showToolButtons;

/// 隐藏工具按钮
- (void)hideToolButtons;

/// 显示网络监控
- (void)showNetworkMonitor;

/// 显示文件浏览器
- (void)showFileBrowser;

/// 显示数据库查看器
- (void)showDatabaseViewer;

/// 显示崩溃记录
- (void)showCrashRecords;

/// 显示缓存清理
- (void)showCacheCleaner;

/// 显示日志查看器
- (void)showLogViewer;

/// 显示性能监控
- (void)showPerformance;

@end

NS_ASSUME_NONNULL_END