#import <UIKit/UIKit.h>
#import "RTBExplorerToolbar.h"

@class RTBExplorerViewController;

@protocol RTBExplorerViewControllerDelegate <NSObject>
@optional
- (void)explorerViewControllerDidFinish:(RTBExplorerViewController *)viewController;
@end

@interface RTBExplorerViewController : UIViewController

@property (nonatomic, assign) id<RTBExplorerViewControllerDelegate> delegate;
@property (nonatomic, readonly) RTBExplorerToolbar *toolbar;

- (BOOL)shouldReceiveTouchAtWindowPoint:(CGPoint)pointInWindow;

@end