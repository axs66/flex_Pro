#import "RTBWindow.h"
#import "RTBExplorerViewController.h"

@implementation RTBWindow

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    // 确保只有工具栏区域和子视图控制器接收触摸事件
    RTBExplorerViewController *explorerVC = (RTBExplorerViewController *)self.rootViewController;
    BOOL result = [explorerVC shouldReceiveTouchAtWindowPoint:point];
    return result;
}

@end