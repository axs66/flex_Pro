#import <UIKit/UIKit.h>

@interface UIAlertView (Blocks)

+ (UIAlertView *)showAlertWithTitle:(NSString *)title 
                            message:(NSString *)message 
                  cancelButtonTitle:(NSString *)cancelButtonTitle 
                  otherButtonTitles:(NSArray *)otherButtonTitles 
                          onDismiss:(void (^)(int buttonIndex))onDismiss 
                           onCancel:(void (^)(void))onCancel;

@end