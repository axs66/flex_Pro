#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface Toast : NSObject

+ (void)showToast:(NSString *)message;
+ (void)showToast:(NSString *)message duration:(NSTimeInterval)duration;
+ (void)showToastInView:(UIView *)view message:(NSString *)message;

@end

NS_ASSUME_NONNULL_END