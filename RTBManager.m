#import "RTBManager.h"
#import "RTBExplorerViewController.h"
#import "RTBWindow.h"
#import "RTBRuntime.h"
#import "Toast.h"
#import <objc/runtime.h>
#import "RTBClass.h"
#import "RTBMethod.h"
#import "RTBProperty.h"
#import "RTBRuntime+Optimization.h"

@interface RTBRuntime (Private)
- (void)analyzeProtocols:(Class)cls forClass:(RTBClass *)classStub;
- (void)analyzeIvars:(Class)cls forClass:(RTBClass *)classStub;
@end

@interface RTBManager () <RTBExplorerViewControllerDelegate>
@property (nonatomic, strong) RTBWindow *explorerWindow;
@property (nonatomic, strong) RTBRuntime *runtime;
@property (nonatomic, strong) NSMutableArray *rootClasses;
@property (nonatomic, strong) NSMutableDictionary *allClassStubsByName;
@property (nonatomic, strong) RTBExplorerViewController *explorerViewController;
@end

@implementation RTBManager

+ (RTBManager *)sharedManager {
    static RTBManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[RTBManager alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _initializing = NO;
        
        // 预加载Runtime数据
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            [[RTBRuntime sharedInstance] emptyCachesAndReadAllRuntimeClasses];
        });
    }
    return self;
}

- (RTBWindow *)explorerWindow {
    if (!_explorerWindow) {
        _explorerWindow = [[RTBWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        _explorerWindow.windowLevel = UIWindowLevelStatusBar + 100;
        _explorerWindow.backgroundColor = [UIColor clearColor];
        _explorerWindow.rootViewController = self.explorerViewController;
    }
    return _explorerWindow;
}

- (RTBExplorerViewController *)explorerViewController {
    if (!_explorerViewController) {
        _explorerViewController = [[RTBExplorerViewController alloc] init];
        _explorerViewController.delegate = self;
    }
    return _explorerViewController;
}

- (void)showExplorer {
    if (self.isInitializing) {
        [Toast showToast:@"RuntimeBrowser正在初始化，请稍候..."];
        return;
    }
    
    // 修改这里：使用类方法调用isRuntimeReady
    if (![RTBRuntime isRuntimeReady]) {
        self.initializing = YES;
        [Toast showToast:@"正在加载Runtime数据..."];
        
        // 确认这个方法是实例方法
        [[RTBRuntime sharedInstance] readAllRuntimeClassesAsync:^(BOOL success) {
            self.initializing = NO;
            if (success) {
                [self performShowExplorer];
                [Toast showToast:@"RuntimeBrowser已就绪"];
            } else {
                [Toast showToast:@"RuntimeBrowser初始化失败"];
            }
        }];
    } else {
        [self performShowExplorer];
    }
}

- (void)performShowExplorer {
    self.explorerWindow.hidden = NO;
    [self.explorerWindow makeKeyAndVisible];
}

- (void)hideExplorer {
    self.explorerWindow.hidden = YES;
    // 不立即释放，保持状态
}

- (void)toggleExplorer {
    if (self.explorerWindow.isHidden) {
        [self showExplorer];
    } else {
        [self hideExplorer];
    }
}

- (BOOL)isHidden {
    return self.explorerWindow.isHidden;
}

- (void)explorerViewControllerDidFinish:(RTBExplorerViewController *)viewController {
    [self hideExplorer];
}

@end