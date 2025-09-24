#import <UIKit/UIKit.h>

@class RTBExplorerViewController;
@class RTBWindow;
@class RTBRuntime;

@interface RTBManager : NSObject

@property (nonatomic, assign, getter=isInitializing) BOOL initializing;
@property (nonatomic, strong, readonly) RTBExplorerViewController *explorerViewController;
@property (nonatomic, strong, readonly) RTBWindow *explorerWindow;
@property (nonatomic, strong, readonly) RTBRuntime *runtime;

+ (RTBManager *)sharedManager;
- (void)showExplorer;
- (void)hideExplorer;
- (void)toggleExplorer;
- (BOOL)isHidden;
- (void)performShowExplorer;

@end