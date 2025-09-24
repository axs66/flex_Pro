#import <UIKit/UIKit.h>
#import "FLEX/FLEX.h"

// 声明我们将在后面用到的私有方法
@interface FLEXManager (Private)
+ (void)flex_setupGesture;
+ (void)flex_hookAPNSMethods;
@end

// 使用 %ctor 构造函数来注册通知
%ctor {
    // 在 %ctor 中只做一件事：注册一个当 App 启动完成后执行的通知。
    // 这是最安全的实践。
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        
        NSLog(@"[FLEX Tweak] App did finish launching. Initializing FLEX...");

        // 三指手势来显示/隐藏 FLEX
        // 这个方法现在可以安全调用了，因为它会在 App 启动后执行
        if ([FLEXManager respondsToSelector:@selector(flex_setupGesture)]) {
            [FLEXManager flex_setupGesture];
        }

        //  APNS (推送通知) 拦截
        // 同样，现在 Hook AppDelegate 是安全的
        if ([FLEXManager respondsToSelector:@selector(flex_hookAPNSMethods)]) {
            [FLEXManager flex_hookAPNSMethods];
        }

        // FLEX 窗口在 App 启动时就自动显示
        // [[FLEXManager sharedManager] showExplorer];
        
        NSLog(@"[FLEX Tweak] Initialization complete.");
    }];
}