#import "UIAlertView+RTB.h"
#import <objc/runtime.h>

static char kRTBLeftButtonActionKey;
static char kRTBRightButtonActionKey;

@implementation UIAlertView (RTB)

+ (void)rtb_displayAlertWithTitle:(NSString *)title
                          message:(NSString *)message
                  leftButtonTitle:(NSString *)leftButtonTitle
                 leftButtonAction:(void (^)(void))leftButtonAction
                 rightButtonTitle:(NSString *)rightButtonTitle
                rightButtonAction:(void (^)(NSString *))rightButtonAction {
    
    // 在iOS 9及以上，UIAlertView已弃用，使用UIAlertController
    if (@available(iOS 9.0, *)) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        
        // 添加文本输入框
        [alertController addTextFieldWithConfigurationHandler:nil];
        
        // 添加左按钮（取消）
        [alertController addAction:[UIAlertAction actionWithTitle:leftButtonTitle
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {
                                                             if (leftButtonAction) {
                                                                 leftButtonAction();
                                                             }
                                                         }]];
        
        // 添加右按钮
        [alertController addAction:[UIAlertAction actionWithTitle:rightButtonTitle
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
                                                             if (rightButtonAction) {
                                                                 NSString *text = alertController.textFields.firstObject.text;
                                                                 rightButtonAction(text);
                                                             }
                                                         }]];
        
        // 显示提示框
        UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topVC.presentedViewController) {
            topVC = topVC.presentedViewController;
        }
        [topVC presentViewController:alertController animated:YES completion:nil];
    } else {
        // 旧版本使用UIAlertView
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:[self class]
                                                  cancelButtonTitle:leftButtonTitle
                                                  otherButtonTitles:rightButtonTitle, nil];
        alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
        
        // 存储回调块
        objc_setAssociatedObject(alertView, &kRTBLeftButtonActionKey, leftButtonAction, OBJC_ASSOCIATION_COPY);
        objc_setAssociatedObject(alertView, &kRTBRightButtonActionKey, rightButtonAction, OBJC_ASSOCIATION_COPY);
        
        [alertView show];
    }
}

@end