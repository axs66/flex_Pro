//
//  FLEXCompatibility.h
//  FLEX
//

#import <UIKit/UIKit.h>

// 版本检查宏（不会触发编译器警告）
#define FLEX_AT_LEAST_IOS11 (([[[UIDevice currentDevice] systemVersion] floatValue] >= 11.0))
#define FLEX_AT_LEAST_IOS13 (([[[UIDevice currentDevice] systemVersion] floatValue] >= 13.0))

// 兼容性类声明
@interface FLEXCompatibility : NSObject

// 系统颜色兼容方法
+ (UIColor *)systemBackgroundColor;
+ (UIColor *)labelColor;
+ (UIColor *)secondaryLabelColor;
+ (UIColor *)systemRedColor;
+ (UIColor *)systemGreenColor;
+ (UIColor *)systemBlueColor;
+ (UIColor *)systemOrangeColor;
+ (UIColor *)systemGrayColor;
+ (UIColor *)separatorColor;
+ (UIColor *)secondarySystemBackgroundColor;

// 安全区域兼容方法
+ (NSLayoutYAxisAnchor *)safeAreaTopAnchorForViewController:(UIViewController *)viewController;
+ (NSLayoutYAxisAnchor *)safeAreaBottomAnchorForViewController:(UIViewController *)viewController;
+ (NSLayoutXAxisAnchor *)safeAreaLeadingAnchorForViewController:(UIViewController *)viewController;
+ (NSLayoutXAxisAnchor *)safeAreaTrailingAnchorForViewController:(UIViewController *)viewController;

// 字体兼容方法
+ (UIFont *)monospacedSystemFontOfSize:(CGFloat)fontSize weight:(UIFontWeight)weight;

// 系统图标兼容方法
+ (UIImage *)systemImageNamed:(NSString *)name fallbackImageNamed:(NSString *)fallbackName;

@end

// 将宏定义为调用方法，这样可以避免编译器的可用性检查
#define FLEXSystemBackgroundColor [FLEXCompatibility systemBackgroundColor]
#define FLEXLabelColor [FLEXCompatibility labelColor]
#define FLEXSecondaryLabelColor [FLEXCompatibility secondaryLabelColor]
#define FLEXSystemRedColor [FLEXCompatibility systemRedColor]
#define FLEXSystemGreenColor [FLEXCompatibility systemGreenColor]
#define FLEXSystemBlueColor [FLEXCompatibility systemBlueColor]
#define FLEXSystemOrangeColor [FLEXCompatibility systemOrangeColor]
#define FLEXSystemGrayColor [FLEXCompatibility systemGrayColor]
#define FLEXSeparatorColor [FLEXCompatibility separatorColor]
#define FLEXSecondarySystemBackgroundColor [FLEXCompatibility secondarySystemBackgroundColor]

// 安全区域兼容宏
#define FLEXSafeAreaTopAnchor(vc) [FLEXCompatibility safeAreaTopAnchorForViewController:(vc)]
#define FLEXSafeAreaBottomAnchor(vc) [FLEXCompatibility safeAreaBottomAnchorForViewController:(vc)]
#define FLEXSafeAreaLeadingAnchor(vc) [FLEXCompatibility safeAreaLeadingAnchorForViewController:(vc)]
#define FLEXSafeAreaTrailingAnchor(vc) [FLEXCompatibility safeAreaTrailingAnchorForViewController:(vc)]