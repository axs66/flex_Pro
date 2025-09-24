#import <UIKit/UIKit.h>

@interface UIAlertView (RTB)

+ (void)rtb_displayAlertWithTitle:(NSString *)title
                          message:(NSString *)message
                  leftButtonTitle:(NSString *)leftButtonTitle
                 leftButtonAction:(void (^)(void))leftButtonAction
                 rightButtonTitle:(NSString *)rightButtonTitle
                rightButtonAction:(void (^)(NSString *))rightButtonAction;

@end