#import "Manager.h"

@implementation Manager

+ (UIViewController *)getActiveTopController {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    // 处理 UINavigationController
    if ([topController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navController = (UINavigationController *)topController;
        return navController.topViewController ?: navController;
    }
    
    // 处理 UITabBarController
    if ([topController isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabController = (UITabBarController *)topController;
        return tabController.selectedViewController ?: tabController;
    }
    
    return topController;
}

@end