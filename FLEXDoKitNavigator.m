#import "FLEXDoKitNavigator.h"
#import "FLEXDoKitNetworkViewController.h" 
#import "FLEXDoKitFileBrowserViewController.h"
#import "FLEXDoKitDatabaseViewController.h"
#import "FLEXDoKitCrashViewController.h"
#import "FLEXDoKitCleanViewController.h"
#import "FLEXDoKitLogViewController.h"
#import "FLEXDoKitPerformanceViewController.h"
#import "FLEXDoKitNetworkMonitor.h"
#import "FLEXDoKitLogViewer.h"
#import "FLEXManager.h"
#import "FLEXManager+DoKit.h"
#import "FLEXCompatibility.h"

@interface FLEXDoKitNavigator ()
@property (nonatomic, strong) UIWindow *navigatorWindow;
@property (nonatomic, strong) UIButton *doKitButton;
@property (nonatomic, strong) NSMutableArray<UIView *> *toolButtons;
@property (nonatomic, assign) CGPoint buttonOrigin;
@property (nonatomic, assign) BOOL isShowingToolButtons;
@property (nonatomic, assign) BOOL isDragging;
@end

@implementation FLEXDoKitNavigator

+ (instancetype)sharedNavigator {
    static FLEXDoKitNavigator *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _toolButtons = [NSMutableArray array];
        _buttonOrigin = CGPointMake(20, 120);
        _isShowingToolButtons = NO;
        _isDragging = NO;
        
        [self setupNavigatorWindow];
    }
    return self;
}

- (void)setupNavigatorWindow {
    self.navigatorWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.navigatorWindow.windowLevel = UIWindowLevelStatusBar + 100;
    self.navigatorWindow.hidden = YES;
    self.navigatorWindow.backgroundColor = [UIColor clearColor];
    
    // 创建入口按钮
    self.doKitButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.doKitButton.frame = CGRectMake(_buttonOrigin.x, _buttonOrigin.y, 60, 60);
    self.doKitButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.7 blue:1.0 alpha:0.8];
    self.doKitButton.layer.cornerRadius = 30;
    self.doKitButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.doKitButton.layer.shadowOffset = CGSizeMake(2, 2);
    self.doKitButton.layer.shadowOpacity = 0.5;
    self.doKitButton.layer.shadowRadius = 3;
    [self.doKitButton setTitle:@"DoKit" forState:UIControlStateNormal];
    [self.doKitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.doKitButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    
    // 添加手势和点击事件
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.doKitButton addGestureRecognizer:panGesture];
    
    [self.doKitButton addTarget:self action:@selector(doKitButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    [self.navigatorWindow addSubview:self.doKitButton];
    
    // 创建工具按钮
    [self createToolButtons];
}

- (void)show {
    self.navigatorWindow.hidden = NO;
}

- (void)hide {
    self.navigatorWindow.hidden = YES;
    [self hideToolButtons];
}

- (void)createToolButtons {
    // 清除现有按钮
    for (UIView *button in self.toolButtons) {
        [button removeFromSuperview];
    }
    [self.toolButtons removeAllObjects];
    
    NSArray *buttonData = @[
        @{@"title": @"网络", @"selectorName": @"showNetworkMonitor"},
        @{@"title": @"文件", @"selectorName": @"showFileBrowser"},
        @{@"title": @"数据库", @"selectorName": @"showDatabaseViewer"},
        @{@"title": @"崩溃", @"selectorName": @"showCrashRecords"},
        @{@"title": @"清理", @"selectorName": @"showCacheCleaner"},
        @{@"title": @"日志", @"selectorName": @"showLogViewer"},
        @{@"title": @"性能", @"selectorName": @"showPerformance"}
    ];
    
    CGFloat buttonSize = 50;
    
    for (NSInteger i = 0; i < buttonData.count; i++) {
        NSDictionary *data = buttonData[i];
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(self.doKitButton.frame.origin.x, self.doKitButton.frame.origin.y, buttonSize, buttonSize);
        button.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.9 alpha:0.9];
        button.layer.cornerRadius = buttonSize / 2;
        [button setTitle:data[@"title"] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:12];
        button.alpha = 0;
        button.tag = i;
        
        [self.navigatorWindow addSubview:button];
        [self.toolButtons addObject:button];
    }
}

- (void)showToolButtons {
    if (self.isShowingToolButtons) return;
    self.isShowingToolButtons = YES;
    
    CGFloat radius = 120;
    CGFloat centerX = self.doKitButton.center.x;
    CGFloat centerY = self.doKitButton.center.y;
    
    NSInteger totalButtons = self.toolButtons.count;
    CGFloat angleStep = M_PI / (totalButtons - 1);
    
    [UIView animateWithDuration:0.3 animations:^{
        for (NSInteger i = 0; i < totalButtons; i++) {
            UIView *button = self.toolButtons[i];
            CGFloat angle = M_PI / 2 + angleStep * i;
            CGFloat x = centerX + radius * cos(angle) - button.frame.size.width / 2;
            CGFloat y = centerY - radius * sin(angle) - button.frame.size.height / 2;
            
            button.frame = CGRectMake(x, y, button.frame.size.width, button.frame.size.height);
            button.alpha = 1.0;
        }
    }];
}

- (void)hideToolButtons {
    if (!self.isShowingToolButtons) return;
    self.isShowingToolButtons = NO;
    
    [UIView animateWithDuration:0.3 animations:^{
        for (UIView *button in self.toolButtons) {
            button.frame = CGRectMake(self.doKitButton.frame.origin.x, self.doKitButton.frame.origin.y, button.frame.size.width, button.frame.size.height);
            button.alpha = 0;
        }
    }];
}

#pragma mark - 手势处理

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.navigatorWindow];
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            self.isDragging = YES;
            [self hideToolButtons];
            break;
            
        case UIGestureRecognizerStateChanged: {
            CGPoint newCenter = CGPointMake(self.doKitButton.center.x + translation.x,
                                           self.doKitButton.center.y + translation.y);
            self.doKitButton.center = newCenter;
            [gesture setTranslation:CGPointZero inView:self.navigatorWindow];
            break;
        }
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            self.isDragging = NO;
            
            // 调整位置，吸附到屏幕边缘
            CGRect buttonFrame = self.doKitButton.frame;
            CGRect screenBounds = [UIScreen mainScreen].bounds;
            CGFloat minX = 0;
            CGFloat maxX = screenBounds.size.width - buttonFrame.size.width;
            CGFloat minY = 44; // 状态栏高度
            CGFloat maxY = screenBounds.size.height - buttonFrame.size.height;
            
            CGFloat targetX;
            if (buttonFrame.origin.x < screenBounds.size.width / 2) {
                targetX = minX;
            } else {
                targetX = maxX;
            }
            
            CGFloat targetY = MAX(minY, MIN(buttonFrame.origin.y, maxY));
            
            [UIView animateWithDuration:0.3 animations:^{
                self.doKitButton.frame = CGRectMake(targetX, targetY, buttonFrame.size.width, buttonFrame.size.height);
            }];
            
            // 保存按钮位置
            self.buttonOrigin = CGPointMake(targetX, targetY);
            break;
        }
            
        default:
            break;
    }
}

#pragma mark - 按钮事件处理

- (void)doKitButtonTapped {
    if (!self.isDragging) {
        if (self.isShowingToolButtons) {
            [self hideToolButtons];
        } else {
            [self showToolButtons];
        }
    }
}

- (void)showNetworkMonitor {
    [self hideToolButtons];
    UIViewController *viewController = [[FLEXDoKitNetworkViewController alloc] init];
    [self presentViewController:viewController];
}

- (void)showFileBrowser {
    [self hideToolButtons];
    UIViewController *viewController = [[FLEXDoKitFileBrowserViewController alloc] init];
    [self presentViewController:viewController];
}

- (void)showDatabaseViewer {
    [self hideToolButtons];
    UIViewController *viewController = [[FLEXDoKitDatabaseViewController alloc] init];
    [self presentViewController:viewController];
}

- (void)showCrashRecords {
    [self hideToolButtons];
    UIViewController *viewController = [[FLEXDoKitCrashViewController alloc] init];
    [self presentViewController:viewController];
}

- (void)showCacheCleaner {
    [self hideToolButtons];
    UIViewController *viewController = [[FLEXDoKitCleanViewController alloc] init];
    [self presentViewController:viewController];
}

- (void)showLogViewer {
    [self hideToolButtons];
    UIViewController *viewController = [[FLEXDoKitLogViewController alloc] init];
    [self presentViewController:viewController];
}

- (void)showPerformance {
    [self hideToolButtons];
    UIViewController *viewController = [[FLEXDoKitPerformanceViewController alloc] init];
    [self presentViewController:viewController];
}

- (void)presentViewController:(UIViewController *)viewController {
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    // 添加关闭按钮
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissPresentedController:)];
    viewController.navigationItem.leftBarButtonItem = closeButton;
    
    navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
    [rootViewController presentViewController:navigationController animated:YES completion:nil];
}

- (void)dismissPresentedController:(id)sender {
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    [rootViewController dismissViewControllerAnimated:YES completion:nil];
}

@end