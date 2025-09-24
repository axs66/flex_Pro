//
//  FLEXManager+DoKit.h
//  FLEX
//
//  DoKit 功能扩展
//

#import "FLEXManager.h"

@class FLEXDoKitNetworkMonitor;

NS_ASSUME_NONNULL_BEGIN

/// FLEXManager的DoKit扩展，提供额外功能和集成点
@interface FLEXManager (DoKit)

/// 是否启用DoKit功能
@property (nonatomic, assign) BOOL doKitEnabled;

/// 网络监控器实例
@property (nonatomic, readonly) FLEXDoKitNetworkMonitor *networkMonitor;

/**
 * 初始化DoKit功能
 */
- (void)setupDoKitFeatures;

/**
 * 停止和清理DoKit功能
 */
- (void)teardownDoKitFeatures;

/**
 * 处理DoKit键盘快捷键
 */
- (void)handleDoKitKeyboardShortcut:(NSNotification *)notification;

/**
 * 显示Explorer视图控制器
 * 这是一个便利方法，内部调用showExplorer
 */
- (void)showExplorerViewController;

@end

NS_ASSUME_NONNULL_END