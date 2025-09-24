#import "Toast.h"

@implementation Toast

+ (void)showToast:(NSString *)message {
    [self showToast:message duration:2.0];
}

+ (void)showToast:(NSString *)message duration:(NSTimeInterval)duration {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    [self showToastInView:window message:message duration:duration];
}

+ (void)showToastInView:(UIView *)view message:(NSString *)message {
    [self showToastInView:view message:message duration:2.0];
}

+ (void)showToastInView:(UIView *)view message:(NSString *)message duration:(NSTimeInterval)duration {
    if (!message || message.length == 0) return;
    
    // 创建一个半透明的黑色背景
    UILabel *toastLabel = [[UILabel alloc] init];
    toastLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    toastLabel.textColor = [UIColor whiteColor];
    toastLabel.textAlignment = NSTextAlignmentCenter;
    toastLabel.font = [UIFont systemFontOfSize:14];
    toastLabel.text = message;
    toastLabel.numberOfLines = 0;
    toastLabel.layer.cornerRadius = 8;
    toastLabel.layer.masksToBounds = YES;
    
    // 计算文本大小
    CGSize maxSize = CGSizeMake(view.bounds.size.width - 80, view.bounds.size.height / 2);
    CGRect textRect = [message boundingRectWithSize:maxSize
                                            options:NSStringDrawingUsesLineFragmentOrigin
                                         attributes:@{NSFontAttributeName:toastLabel.font}
                                            context:nil];
    
    // 设置 Toast 大小
    CGFloat width = textRect.size.width + 40;
    CGFloat height = textRect.size.height + 20;
    toastLabel.frame = CGRectMake((view.bounds.size.width - width) / 2, 
                                 view.bounds.size.height - 100 - height, 
                                 width, height);
    
    // 添加到视图
    [view addSubview:toastLabel];
    
    // 动画显示和消失
    toastLabel.alpha = 0;
    [UIView animateWithDuration:0.3 animations:^{
        toastLabel.alpha = 1;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 delay:duration options:0 animations:^{
            toastLabel.alpha = 0;
        } completion:^(BOOL finished) {
            [toastLabel removeFromSuperview];
        }];
    }];
}

@end