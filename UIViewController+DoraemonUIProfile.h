//
//  UIViewController+DoraemonUIProfile.h
//  FLEX_Pro
//
//  Created on 2025/6/9.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (DoraemonUIProfile)

// 用于UI性能监控的类方法
+ (void)startDoraemonUIProfileMonitoring;
+ (void)stopDoraemonUIProfileMonitoring;

// 视图生命周期性能监控方法
- (void)doraemon_profileViewDidAppear;
- (void)doraemon_profileViewWillDisappear;

@end

NS_ASSUME_NONNULL_END