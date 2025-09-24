//
//  RTBAppDelegate.m
//  RuntimeBrowser
//
//  Created for RuntimeBrowser project
//

#import "RTBAppDelegate.h"

@implementation RTBAppDelegate

- (void)useClass:(NSString *)className {
    // 这里实现类的使用逻辑
    NSLog(@"使用类: %@", className);
    
    // 创建弹窗显示类名
    UIAlertController *alert = [UIAlertController 
                               alertControllerWithTitle:@"使用类"
                               message:[NSString stringWithFormat:@"正在使用类: %@", className]
                               preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" 
                                            style:UIAlertActionStyleDefault 
                                          handler:nil]];
    
    // 在主窗口的根视图控制器上显示弹窗
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
                break;
            }
        }
    } else {
        window = [[UIApplication sharedApplication] windows].firstObject;
    }
    
    [window.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (void)saveHeadersToDirectoryWithPath:(NSString *)path {
    // 保存头文件的实现
    NSLog(@"保存头文件到路径: %@", path);
}

- (NSString *)headerPathForClass:(NSString *)className {
    // 返回类头文件的路径
    return [NSString stringWithFormat:@"/headers/%@.h", className];
}

@end