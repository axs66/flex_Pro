#import "RTBExplorerViewController.h"
#import "Manager.h"
#import "RuntimeBrowserFactory.h"
#import "RuntimeBrowserFactory+Enhanced.h"
#import "Toast.h"
#import "RTBSystemAnalysisViewController.h"
#import "RTBTreeTVC.h"
#import "RTBObjectsTVC.h"
#import "RTBClassDisplayVC.h"
#import "RTBRuntime.h"
#import "RTBClass.h"

@interface RTBExplorerViewController ()
@property (nonatomic, strong) RTBExplorerToolbar *toolbar;
@property (nonatomic, assign) CGPoint toolbarOriginalCenter;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@end

@implementation RTBExplorerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    
    // 创建工具栏
    [self setupToolbar];
    
    // 创建加载指示器
    [self setupLoadingIndicator];
    
    // 绑定按钮事件
    [self bindButtonEvents];
}

- (void)setupToolbar {
    CGFloat toolbarWidth = MIN(340, self.view.bounds.size.width - 40);
    CGFloat toolbarHeight = 60;
    CGFloat x = (self.view.bounds.size.width - toolbarWidth) / 2;
    CGFloat y = 80;
    
    _toolbar = [[RTBExplorerToolbar alloc] initWithFrame:CGRectMake(x, y, toolbarWidth, toolbarHeight)];
    [self.view addSubview:_toolbar];
    
    // 添加拖动手势
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] 
                                         initWithTarget:self 
                                         action:@selector(handleToolbarPan:)];
    [_toolbar.dragHandle addGestureRecognizer:panGesture];
}

- (void)setupLoadingIndicator {
    _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _loadingIndicator.color = [UIColor whiteColor];
    _loadingIndicator.hidesWhenStopped = YES;
    _loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_loadingIndicator];
    
    [NSLayoutConstraint activateConstraints:@[
        [_loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)bindButtonEvents {
    [_toolbar.hierarchyButton addTarget:self action:@selector(showClassHierarchy) 
                       forControlEvents:UIControlEventTouchUpInside];
    [_toolbar.inspectButton addTarget:self action:@selector(inspectCurrentView) 
                     forControlEvents:UIControlEventTouchUpInside];
    [_toolbar.generateButton addTarget:self action:@selector(showGenerateOptions) 
                      forControlEvents:UIControlEventTouchUpInside];
    [_toolbar.searchButton addTarget:self action:@selector(showClassSearch) 
                    forControlEvents:UIControlEventTouchUpInside];
    [_toolbar.closeButton addTarget:self action:@selector(closeExplorer) 
                   forControlEvents:UIControlEventTouchUpInside];
}

- (void)handleToolbarPan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.view];
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.toolbarOriginalCenter = self.toolbar.center;
        // 添加视觉反馈
        [UIView animateWithDuration:0.1 animations:^{
            self.toolbar.alpha = 0.8;
        }];
    }
    
    CGPoint newCenter = CGPointMake(self.toolbarOriginalCenter.x + translation.x, 
                                   self.toolbarOriginalCenter.y + translation.y);
    
    // 边界限制
    CGFloat margin = 20;
    CGFloat minX = self.toolbar.frame.size.width / 2 + margin;
    CGFloat maxX = self.view.bounds.size.width - minX;
    CGFloat minY = self.toolbar.frame.size.height / 2 + margin;
    CGFloat maxY = self.view.bounds.size.height - self.toolbar.frame.size.height / 2 - margin;
    
    newCenter.x = MAX(minX, MIN(maxX, newCenter.x));
    newCenter.y = MAX(minY, MIN(maxY, newCenter.y));
    
    self.toolbar.center = newCenter;
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        // 恢复透明度
        [UIView animateWithDuration:0.2 animations:^{
            self.toolbar.alpha = 1.0;
        }];
        
        // 保存位置
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setFloat:newCenter.x forKey:@"RTBToolbarCenterX"];
        [defaults setFloat:newCenter.y forKey:@"RTBToolbarCenterY"];
        [defaults synchronize];
    }
}

#pragma mark - Button Actions

- (void)showClassHierarchy {
    [self showLoadingWithMessage:@"正在加载类层次结构..."];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            RTBTreeTVC *treeVC = [RuntimeBrowserFactory createClassHierarchyBrowser];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideLoading];
                
                if (treeVC) {
                    [self presentViewControllerWithNavigation:treeVC title:@"类层次结构"];
                } else {
                    [Toast showToast:@"无法创建类层次浏览器"];
                }
            });
        } @catch (NSException *exception) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideLoading];
                [Toast showToast:@"加载类层次结构失败"];
            });
        }
    });
}

- (void)inspectCurrentView {
    UIViewController *topVC = [Manager getActiveTopController];
    
    UIAlertController *alert = [UIAlertController 
                              alertControllerWithTitle:@"选择检查对象" 
                              message:@"请选择要检查的对象类型" 
                              preferredStyle:UIAlertControllerStyleActionSheet];
    
    // 当前视图控制器
    [alert addAction:[UIAlertAction actionWithTitle:@"当前视图控制器" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        [self inspectObject:topVC withTitle:@"视图控制器"];
    }]];
    
    // 当前视图
    [alert addAction:[UIAlertAction actionWithTitle:@"当前视图" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        [self inspectObject:topVC.view withTitle:@"视图"];
    }]];
    
    // 根窗口
    [alert addAction:[UIAlertAction actionWithTitle:@"主窗口" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        [self inspectObject:keyWindow withTitle:@"主窗口"];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" 
                                             style:UIAlertActionStyleCancel 
                                           handler:nil]];
    
    // iPad支持
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = _toolbar.inspectButton;
        alert.popoverPresentationController.sourceRect = _toolbar.inspectButton.bounds;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)inspectObject:(id)object withTitle:(NSString *)title {
    [self showLoadingWithMessage:[NSString stringWithFormat:@"正在检查%@...", title]];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            RTBObjectsTVC *objVC = [RuntimeBrowserFactory createObjectBrowserForObject:object];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideLoading];
                
                if (objVC) {
                    [self presentViewControllerWithNavigation:objVC title:title];
                } else {
                    [Toast showToast:@"无法创建对象浏览器"];
                }
            });
        } @catch (NSException *exception) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideLoading];
                [Toast showToast:[NSString stringWithFormat:@"检查%@失败", title]];
            });
        }
    });
}

- (void)showGenerateOptions {
    UIAlertController *alert = [UIAlertController 
                              alertControllerWithTitle:@"生成头文件" 
                              message:@"请输入要生成头文件的类名" 
                              preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"例如: UIViewController";
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" 
                                             style:UIAlertActionStyleCancel 
                                           handler:nil]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"生成" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        NSString *className = alert.textFields.firstObject.text;
        [self generateHeaderForClassName:className];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)generateHeaderForClassName:(NSString *)className {
    if (className.length == 0) {
        [Toast showToast:@"请输入类名"];
        return;
    }
    
    [self showLoadingWithMessage:@"正在生成头文件..."];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            Class cls = NSClassFromString(className);
            if (cls) {
                NSString *header = [RuntimeBrowserFactory generateHeaderForClass:cls];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self hideLoading];
                    [self showHeaderString:header forClassName:className];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self hideLoading];
                    [Toast showToast:@"找不到指定的类"];
                });
            }
        } @catch (NSException *exception) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideLoading];
                [Toast showToast:@"生成头文件失败"];
            });
        }
    });
}

- (void)showHeaderString:(NSString *)header forClassName:(NSString *)className {
    RTBClassDisplayVC *displayVC = [[RTBClassDisplayVC alloc] init];
    displayVC.className = className;
    displayVC.title = [NSString stringWithFormat:@"%@.h", className];
    
    [self presentViewControllerWithNavigation:displayVC title:displayVC.title];
}

- (void)showClassSearch {
    UIAlertController *alert = [UIAlertController 
                              alertControllerWithTitle:@"搜索类" 
                              message:@"请输入要搜索的类名关键词" 
                              preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"例如: View, Controller";
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" 
                                             style:UIAlertActionStyleCancel 
                                           handler:nil]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"搜索" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        NSString *searchTerm = alert.textFields.firstObject.text;
        [self performClassSearch:searchTerm];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performClassSearch:(NSString *)searchTerm {
    if (searchTerm.length == 0) {
        [Toast showToast:@"请输入搜索关键词"];
        return;
    }
    
    [self showLoadingWithMessage:@"正在搜索类..."];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            // 执行搜索逻辑
            RTBRuntime *runtime = [RTBRuntime sharedInstance];
            NSArray *allClassStubs = [runtime sortedClassStubs];
            NSMutableArray *results = [NSMutableArray array];
            
            for (RTBClass *classStub in allClassStubs) {
                if ([classStub.classObjectName localizedCaseInsensitiveContainsString:searchTerm]) {
                    [results addObject:classStub];
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideLoading];
                [self showSearchResults:results forTerm:searchTerm];
            });
        } @catch (NSException *exception) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideLoading];
                [Toast showToast:@"搜索失败"];
            });
        }
    });
}

- (void)showSearchResults:(NSArray *)results forTerm:(NSString *)searchTerm {
    if (results.count == 0) {
        [Toast showToast:[NSString stringWithFormat:@"未找到包含\"%@\"的类", searchTerm]];
        return;
    }
    
    UIAlertController *alert = [UIAlertController 
                              alertControllerWithTitle:@"搜索结果" 
                              message:[NSString stringWithFormat:@"找到 %lu 个相关类", (unsigned long)results.count] 
                              preferredStyle:UIAlertControllerStyleActionSheet];
    
    // 限制显示数量，避免界面过长
    NSInteger maxDisplay = MIN(results.count, 10);
    for (NSInteger i = 0; i < maxDisplay; i++) {
        RTBClass *classStub = results[i];
        [alert addAction:[UIAlertAction actionWithTitle:classStub.classObjectName 
                                                 style:UIAlertActionStyleDefault 
                                               handler:^(UIAlertAction * _Nonnull action) {
            Class cls = NSClassFromString(classStub.classObjectName);
            if (cls) {
                RTBClassDisplayVC *displayVC = [RuntimeBrowserFactory createClassDisplayViewControllerForClass:cls];
                [self presentViewControllerWithNavigation:displayVC title:classStub.classObjectName];
            }
        }]];
    }
    
    if (results.count > maxDisplay) {
        [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"还有 %lu 个结果...", (unsigned long)(results.count - maxDisplay)] 
                                                 style:UIAlertActionStyleDefault 
                                               handler:^(UIAlertAction * _Nonnull action) {
            [Toast showToast:@"请缩小搜索范围"];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" 
                                             style:UIAlertActionStyleCancel 
                                           handler:nil]];
    
    // iPad支持
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = _toolbar.searchButton;
        alert.popoverPresentationController.sourceRect = _toolbar.searchButton.bounds;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)closeExplorer {
    if ([self.delegate respondsToSelector:@selector(explorerViewControllerDidFinish:)]) {
        [self.delegate explorerViewControllerDidFinish:self];
    }
}

#pragma mark - Helper Methods

- (void)presentViewControllerWithNavigation:(UIViewController *)viewController title:(NSString *)title {
    UINavigationController *navController = [[UINavigationController alloc] 
                                           initWithRootViewController:viewController];
    
    viewController.title = title;
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] 
                                  initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                     target:self 
                                                     action:@selector(dismissPresentedController)];
    viewController.navigationItem.rightBarButtonItem = doneButton;
    
    navController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)dismissPresentedController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showLoadingWithMessage:(NSString *)message {
    [_loadingIndicator startAnimating];
    if (message) {
        [Toast showToast:message];
    }
}

- (void)hideLoading {
    [_loadingIndicator stopAnimating];
}

- (BOOL)shouldReceiveTouchAtWindowPoint:(CGPoint)pointInWindow {
    CGPoint pointInView = [self.view convertPoint:pointInWindow fromView:nil];
    
    // 检查是否在工具栏区域
    if (CGRectContainsPoint(self.toolbar.frame, pointInView)) {
        return YES;
    }
    
    // 检查是否有呈现的视图控制器
    if (self.presentedViewController) {
        return YES;
    }
    
    return NO;
}

- (void)showMethodProfiler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"方法性能分析"
                                                                   message:@"开始监控方法执行时间"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"开始" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [RuntimeBrowserFactory startMethodProfiler];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"停止并查看结果" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [RuntimeBrowserFactory stopMethodProfiler];
        NSArray *methodResults = [RuntimeBrowserFactory getProfiledMethodResults];
        if (methodResults && methodResults.count > 0) {
            // 显示方法分析结果，例如:
            UIViewController *resultsVC = [[UIViewController alloc] init];
            resultsVC.title = @"方法分析结果";
            [self presentViewControllerWithNavigation:resultsVC title:@"方法分析结果"];
        } else {
            [Toast showToast:@"未捕获到方法调用信息"];
        }
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

// 在现有功能基础上添加DoKit增强功能

- (void)showDoKitFeatures {
    UIAlertController *alert = [UIAlertController 
                              alertControllerWithTitle:@"DoKit增强功能" 
                              message:@"选择要使用的功能" 
                              preferredStyle:UIAlertControllerStyleActionSheet];
    
    // Hook检测
    [alert addAction:[UIAlertAction actionWithTitle:@"Hook检测器" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        UIViewController *vc = [RuntimeBrowserFactory createHookDetectorViewController];
        [self presentViewControllerWithNavigation:vc title:@"Hook检测器"];
    }]];
    
    // 网络分析
    [alert addAction:[UIAlertAction actionWithTitle:@"网络分析器" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        UIViewController *vc = [RuntimeBrowserFactory createNetworkAnalyzerViewController];
        [self presentViewControllerWithNavigation:vc title:@"网络分析器"];
    }]];
    
    // 性能监控
    [alert addAction:[UIAlertAction actionWithTitle:@"性能监控" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        UIViewController *vc = [RuntimeBrowserFactory createPerformanceMonitorViewController];
        [self presentViewControllerWithNavigation:vc title:@"性能监控"];
    }]];
    
    // 内存分析
    [alert addAction:[UIAlertAction actionWithTitle:@"内存分析器" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        UIViewController *vc = [RuntimeBrowserFactory createMemoryAnalyzerViewController];
        [self presentViewControllerWithNavigation:vc title:@"内存分析器"];
    }]];
    
    // 系统分析
    [alert addAction:[UIAlertAction actionWithTitle:@"系统全面分析" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        [self showSystemAnalysis];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" 
                                             style:UIAlertActionStyleCancel 
                                           handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSystemAnalysis {
    [self showLoadingWithMessage:@"正在进行系统分析..."];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *analysis = [RuntimeBrowserFactory getSystemAnalysis];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideLoading];
            
            RTBSystemAnalysisViewController *vc = [[RTBSystemAnalysisViewController alloc] init];
            vc.analysisData = analysis;
            vc.title = @"系统分析报告";
            
            [self presentViewControllerWithNavigation:vc title:@"系统分析报告"];
        });
    });
}

// 为其他功能添加类似的方法...

@end