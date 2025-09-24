#import "UIAlertView+Blocks.h"
#import <objc/runtime.h>

static char kDismissBlockKey;
static char kCancelBlockKey;

@implementation UIAlertView (Blocks)

+ (UIAlertView *)showAlertWithTitle:(NSString *)title 
                            message:(NSString *)message 
                  cancelButtonTitle:(NSString *)cancelButtonTitle 
                  otherButtonTitles:(NSArray *)otherButtonTitles 
                          onDismiss:(void (^)(int buttonIndex))onDismiss 
                           onCancel:(void (^)(void))onCancel {
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                        message:message
                                                       delegate:[self class]
                                              cancelButtonTitle:cancelButtonTitle
                                              otherButtonTitles:nil];
    
    for (NSString *buttonTitle in otherButtonTitles) {
        [alertView addButtonWithTitle:buttonTitle];
    }
    
    if (onDismiss) {
        objc_setAssociatedObject(alertView, &kDismissBlockKey, onDismiss, OBJC_ASSOCIATION_COPY);
    }
    
    if (onCancel) {
        objc_setAssociatedObject(alertView, &kCancelBlockKey, onCancel, OBJC_ASSOCIATION_COPY);
    }
    
    [alertView show];
    return alertView;
}

@end