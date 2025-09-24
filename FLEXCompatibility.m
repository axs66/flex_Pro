//
//  FLEXCompatibility.m
//  FLEX
//

#import "FLEXCompatibility.h"

@implementation FLEXCompatibility

#pragma mark - 系统颜色兼容方法

+ (UIColor *)systemBackgroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemBackgroundColor];
    }
    return [UIColor whiteColor];
}

+ (UIColor *)labelColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor labelColor];
    }
    return [UIColor blackColor];
}

+ (UIColor *)secondaryLabelColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor secondaryLabelColor];
    }
    return [UIColor colorWithWhite:0.6 alpha:1.0];
}

+ (UIColor *)systemRedColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemRedColor];
    }
    return [UIColor redColor];
}

+ (UIColor *)systemGreenColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemGreenColor];
    }
    return [UIColor colorWithRed:0.0 green:0.8 blue:0.0 alpha:1.0];
}

+ (UIColor *)systemBlueColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemBlueColor];
    }
    return [UIColor blueColor];
}

+ (UIColor *)systemOrangeColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemOrangeColor];
    }
    return [UIColor orangeColor];
}

+ (UIColor *)systemGrayColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemGrayColor];
    }
    return [UIColor colorWithWhite:0.6 alpha:1.0];
}

+ (UIColor *)separatorColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor separatorColor];
    }
    return [UIColor colorWithWhite:0.8 alpha:1.0];
}

+ (UIColor *)secondarySystemBackgroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor secondarySystemBackgroundColor];
    }
    return [UIColor colorWithWhite:0.95 alpha:1.0];
}

#pragma mark - 安全区域兼容方法

+ (NSLayoutYAxisAnchor *)safeAreaTopAnchorForViewController:(UIViewController *)viewController {
    if (@available(iOS 11.0, *)) {
        return viewController.view.safeAreaLayoutGuide.topAnchor;
    }
    return viewController.view.topAnchor;
}

+ (NSLayoutYAxisAnchor *)safeAreaBottomAnchorForViewController:(UIViewController *)viewController {
    if (@available(iOS 11.0, *)) {
        return viewController.view.safeAreaLayoutGuide.bottomAnchor;
    }
    return viewController.view.bottomAnchor;
}

+ (NSLayoutXAxisAnchor *)safeAreaLeadingAnchorForViewController:(UIViewController *)viewController {
    if (@available(iOS 11.0, *)) {
        return viewController.view.safeAreaLayoutGuide.leadingAnchor;
    }
    return viewController.view.leadingAnchor;
}

+ (NSLayoutXAxisAnchor *)safeAreaTrailingAnchorForViewController:(UIViewController *)viewController {
    if (@available(iOS 11.0, *)) {
        return viewController.view.safeAreaLayoutGuide.trailingAnchor;
    }
    return viewController.view.trailingAnchor;
}

#pragma mark - 字体兼容方法

+ (UIFont *)monospacedSystemFontOfSize:(CGFloat)fontSize weight:(UIFontWeight)weight {
    if (@available(iOS 13.0, *)) {
        return [UIFont monospacedSystemFontOfSize:fontSize weight:weight];
    } 
    // 在 iOS 13 以下使用 menlo 作为替代
    return [UIFont fontWithName:@"Menlo" size:fontSize];
}

#pragma mark - 系统图标兼容方法

+ (UIImage *)systemImageNamed:(NSString *)name fallbackImageNamed:(NSString *)fallbackName {
    if (@available(iOS 13.0, *)) {
        UIImage *systemImage = [UIImage systemImageNamed:name];
        if (systemImage) {
            return systemImage;
        }
    }
    // iOS 13 以下或者系统图标不存在时使用fallback
    UIImage *fallback = [UIImage imageNamed:fallbackName];
    if (fallback) {
        return fallback;
    }
    // 最后的备选方案，返回一个简单的占位符
    return [UIImage new];
}

@end