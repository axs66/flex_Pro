//
//  FLEXManager+DoKit.m
//  FLEX
//
//  DoKit 功能扩展实现
//

#import "FLEXManager+DoKit.h"
#import "FLEXDoKitNetworkMonitor.h"
#import <objc/runtime.h>

static const void *DoKitEnabledKey = &DoKitEnabledKey;
static const void *NetworkMonitorKey = &NetworkMonitorKey;

@implementation FLEXManager (DoKit)

- (BOOL)doKitEnabled {
    NSNumber *value = objc_getAssociatedObject(self, DoKitEnabledKey);
    return [value boolValue];
}

- (void)setDoKitEnabled:(BOOL)doKitEnabled {
    objc_setAssociatedObject(self, DoKitEnabledKey, @(doKitEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 根据状态更新DoKit功能
    if (doKitEnabled) {
        [self setupDoKitFeatures];
    } else {
        [self teardownDoKitFeatures];
    }
}

// 实现缺失的networkMonitor属性
- (FLEXDoKitNetworkMonitor *)networkMonitor {
    // 使用关联对象作为实际存储
    FLEXDoKitNetworkMonitor *monitor = objc_getAssociatedObject(self, NetworkMonitorKey);
    if (!monitor) {
        monitor = [[FLEXDoKitNetworkMonitor alloc] init];
        objc_setAssociatedObject(self, NetworkMonitorKey, monitor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return monitor;
}

- (void)setupDoKitFeatures {
    // 初始化DoKit功能
    // 确保网络监视器已经被创建
    [self networkMonitor];
}

- (void)teardownDoKitFeatures {
    // 关闭DoKit功能
    FLEXDoKitNetworkMonitor *monitor = objc_getAssociatedObject(self, NetworkMonitorKey);
    if (monitor) {
        [monitor stopMonitoring];
    }
    objc_setAssociatedObject(self, NetworkMonitorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// 实现缺失的键盘快捷键处理方法
- (void)handleDoKitKeyboardShortcut:(NSNotification *)notification {
    // 处理DoKit键盘快捷键
    NSDictionary *userInfo = notification.userInfo;
    NSString *shortcutKey = userInfo[@"key"];
    
    if ([shortcutKey isEqualToString:@"f"]) {
        [self toggleExplorer];
    }
    else if ([shortcutKey isEqualToString:@"n"]) {
        [[self networkMonitor] toggleNetworkMonitoring];
    }
}

// 实现缺失的showExplorerViewController方法
- (void)showExplorerViewController {
    [self showExplorer];
}

@end