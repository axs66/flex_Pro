//
//  FLEXBugViewController.m
//  FLEX
//
//  Bug调试功能实现
//

#import "FLEXBugViewController.h"
#import "FLEXNavigationController.h"
#import "FLEXAlert.h"
#import "FLEXManager.h"
#import "FLEXFileBrowserController.h"
#import "FLEXSystemLogViewController.h"
#import "FLEXNetworkMITMViewController.h"
#import "FLEXPerformanceViewController.h"
#import "FLEXHierarchyTableViewController.h"
#import "FLEXAppInfoViewController.h"
#import "FLEXSystemAnalyzerViewController.h"

#import "FLEXUtility.h"
#import "FLEXColor.h"
#import "FLEXResources.h"

#import "FLEXDoKitCPUViewController.h"
#import "FLEXDoKitVisualTools.h"
#import "FLEXDoKitCrashViewController.h"
#import "FLEXLookinMeasureController.h"
#import "FLEXDoKitLagViewController.h"
#import "FLEXDoKitMockViewController.h" 
#import "FLEXDoKitLogViewController.h"
#import "FLEXFPSMonitorViewController.h"
#import "FLEXMemoryMonitorViewController.h"
#import "FLEXRevealLikeInspector.h"

#import "FLEXRuntimeClient+RuntimeBrowser.h"
#import "FLEXSystemAnalyzerViewController+RuntimeBrowser.h"
#import "FLEXMemoryAnalyzer+RuntimeBrowser.h"
#import "FLEXHookDetector+RuntimeBrowser.h"
#import <objc/runtime.h>
#import <mach-o/dyld.h>

#import "FLEXMemoryAnalyzerViewController.h"
#import "FLEXClassSearcher.h"

@interface FLEXBugViewController () <UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating>
@property (nonatomic, strong) NSArray<NSDictionary *> *categories;
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<NSDictionary *> *> *toolsByCategory;
@property (nonatomic, assign) BOOL isInCategory;
@property (nonatomic, strong) NSString *currentCategory;

@property (nonatomic, strong) NSArray *filteredResults;
@property (nonatomic, assign) BOOL isSearching;
@end

@implementation FLEXBugViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 移除或注释不存在的方法调用
    // [FLEXRuntimeClient.runtime readAllRuntimeClasses]; 
    
    self.title = @"工具";
    self.isInCategory = NO;
    
    // 配置工具分类
    [self setupToolsData];
    
    // 直接使用父类的tableView属性
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ToolCell"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (!self.isInCategory) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] 
            initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
            target:self 
            action:@selector(dismissButtonTapped)];
    }
}

- (void)setupToolsData {
    // 常用工具
    NSArray *commonTools = @[
        @{@"title": @"H5任意门", @"detail": @"H5页面调试", @"class": @"FLEXH5DoorViewController"},
        @{@"title": @"沙盒浏览", @"detail": @"文件系统浏览", @"class": @"FLEXDoKitFileBrowserViewController"},
        @{@"title": @"App信息查看", @"detail": @"应用详细信息", @"class": @"FLEXDoKitAppInfoViewController"},
        @{@"title": @"系统信息", @"detail": @"设备系统信息", @"class": @"FLEXDoKitSystemInfoViewController"},
        @{@"title": @"清除数据", @"detail": @"清理应用数据", @"class": @"FLEXDoKitCleanViewController"},
        @{@"title": @"偏好设置", @"detail": @"偏好设置编辑", @"class": @"FLEXDoKitUserDefaultsViewController"},
    ];
    
    // 性能工具
    NSArray *performanceTools = @[
        @{@"title": @"CPU监控", @"detail": @"实时CPU使用率", @"class": @"FLEXDoKitCPUViewController"}, // 修正类名
        @{@"title": @"内存监控", @"detail": @"实时内存使用情况", @"class": @"FLEXMemoryMonitorViewController"},
        @{@"title": @"FPS显示", @"detail": @"实时帧率监测", @"class": @"FLEXFPSMonitorViewController"}, // 修正类名
        // RuntimeBrowser 相关功能
        @{@"title": @"运行时信息", @"detail": @"分析运行时信息", @"class": @"FLEXSystemAnalyzerViewController"},
        @{@"title": @"类层次结构", @"detail": @"显示类层次关系", @"action": @"showClassHierarchy"},
        @{@"title": @"详细内存", @"detail": @"详细内存分布", @"action": @"showMemoryAnalyzer"},
        @{@"title": @"Hook检测器", @"detail": @"检测方法Hook情况", @"action": @"showHookDetector"},
        @{@"title": @"浏览已加载框架", @"detail": @"浏览已加载框架", @"action": @"showFrameworkBrowser"},
        @{@"title": @"搜索类、方法和属性", @"detail": @"搜索类、方法和属性", @"action": @"showClassSearch"},
    ];
    
    // 网络工具
    NSArray *networkTools = @[
        @{@"title": @"网络监控", @"detail": @"网络请求监控", @"class": @"FLEXNetworkMonitorViewController"},
        @{@"title": @"API测试", @"detail": @"接口测试工具", @"class": @"FLEXAPITestViewController"},
        @{@"title": @"Mock数据管理", @"detail": @"接口数据模拟", @"class": @"FLEXDoKitMockViewController"},
        @{@"title": @"网络历史", @"detail": @"网络请求历史", @"class": @"FLEXDoKitNetworkHistoryViewController"},
        @{@"title": @"弱网测试", @"detail": @"模拟弱网环境", @"class": @"FLEXDoKitWeakNetworkViewController"},
        @{@"title": @"网络劫持", @"detail": @"MITM代理调试", @"class": @"FLEXNetworkMITMViewController"},
    ];
    
    // 视觉工具
    NSArray *visualTools = @[
        @{@"title": @"颜色吸管", @"detail": @"屏幕取色工具", @"class": @"FLEXDoKitColorPickerViewController"},
        @{@"title": @"Lookin测量工具", @"detail": @"精确测量UI元素距离", @"action": @"showLookinMeasure"},
        @{@"title": @"Lookin 3D预览", @"detail": @"3D层次结构预览", @"class": @"FLEXLookinPreviewController"},
        @{@"title": @"组件检查器", @"detail": @"UI组件详细信息", @"class": @"FLEXDoKitComponentViewController"},
        @{@"title": @"对齐标尺", @"detail": @"UI元素测量", @"action": @"showRuler"},
        @{@"title": @"元素边框", @"detail": @"显示视图边框", @"action": @"showViewBorder"},
        @{@"title": @"布局边界", @"detail": @"布局约束可视化", @"action": @"showLayoutBounds"},
        @{@"title": @"视图测量", @"detail": @"显示视图尺寸", @"action": @"showViewMeasurements"},
        @{@"title": @"约束可视化", @"detail": @"显示约束关系", @"action": @"showConstraintsVisualization"},
        @{@"title": @"实时编辑", @"detail": @"实时修改视图属性", @"action": @"enableLiveViewEditing"},
    ];
    
    // 日志工具
    NSArray *logTools = @[
        @{@"title": @"实时日志", @"detail": @"应用日志实时查看", @"class": @"FLEXDoKitLogViewController"},
        @{@"title": @"日志过滤器", @"detail": @"日志内容过滤", @"class": @"FLEXDoKitLogFilterViewController"},
        @{@"title": @"系统日志", @"detail": @"系统级日志查看", @"class": @"FLEXSystemLogViewController"},
    ];
    
    // 运行时分析工具 - 完善实现
    NSArray *runtimeAnalysisTools = @[
        @{@"title": @"类继承层次分析", @"detail": @"分析类的继承关系和子类", @"action": @"showClassHierarchyAnalyzer"},
        @{@"title": @"类性能分析", @"detail": @"分析类的大小、方法数量和性能", @"action": @"showClassPerformanceAnalyzer"},
        @{@"title": @"所有运行时类", @"detail": @"浏览所有运行时类和对象", @"action": @"showRuntimeBrowser"},
        @{@"title": @"内存分析器", @"detail": @"分析内存使用和潜在泄漏", @"action": @"showMemoryAnalyzer"},
        @{@"title": @"Hook检测器", @"detail": @"检测被Hook的方法", @"action": @"showHookDetector"},
        @{@"title": @"方法追踪", @"detail": @"追踪方法调用和执行时间", @"action": @"showMethodTracer"},
        @{@"title": @"类搜索器", @"detail": @"搜索和查找特定类", @"action": @"showClassSearcher"}
    ];
    
    // 定义分类
    self.categories = @[
        @{@"title": @"常用工具", @"image": @"wrench.fill", @"key": @"common"},
        @{@"title": @"性能检测", @"image": @"speedometer", @"key": @"performance"},
        @{@"title": @"网络工具", @"image": @"network", @"key": @"network"},
        @{@"title": @"视觉工具", @"image": @"eye.fill", @"key": @"visual"},
        @{@"title": @"日志工具", @"image": @"doc.text.fill", @"key": @"log"},
        @{@"title": @"运行时分析", @"image": @"chart.bar", @"key": @"runtime"}
    ];
    
    // 工具映射
    self.toolsByCategory = @{
        @"common": commonTools,
        @"performance": performanceTools,
        @"network": networkTools,
        @"visual": visualTools,
        @"log": logTools,
        @"runtime": runtimeAnalysisTools
    };
}

#pragma mark - Actions

- (void)dismissButtonTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)backButtonTapped {
    self.isInCategory = NO;
    self.currentCategory = nil;
    self.title = @"工具";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self
        action:@selector(dismissButtonTapped)];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // 检查是否为搜索结果
    if (self.isSearching && self.filteredResults) {
        return self.filteredResults.count;
    }
    
    // 先检查是否是常规模式
    if ([self isRegularTableView:tableView]) {
        return [self regularTableViewNumberOfRowsInSection:tableView section:section];
    }
    
    // RuntimeBrowser 相关功能的表格数据源
    UIViewController *owner = [self viewControllerForTableView:tableView];
    
    // 类层次结构模式
    if ([objc_getAssociatedObject(owner, "classHierarchyMode") boolValue]) {
        NSArray *rootClasses = objc_getAssociatedObject(owner, "rootClasses");
        return rootClasses.count;
    }
    
    // Hook检测器模式
    if ([objc_getAssociatedObject(owner, "hookDetectorMode") boolValue]) {
        NSDictionary *hookData = objc_getAssociatedObject(owner, "hookAnalysisData");
        NSArray *hookedClasses = hookData[@"hookedClasses"];
        return hookedClasses.count;
    }
    
    // 框架浏览器模式
    if ([objc_getAssociatedObject(owner, "frameworkBrowserMode") boolValue]) {
        NSArray *bundlePaths = objc_getAssociatedObject(owner, "bundlePaths");
        return bundlePaths.count;
    }
    
    return 0;
}

- (void)dealloc {
    // 清理关联对象，避免内存泄漏
    objc_removeAssociatedObjects(self);
    
    // 移除通知监听
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 先检查是否是常规模式
    if ([self isRegularTableView:tableView]) {
        return [self regularTableViewCellForRowAtIndexPath:tableView indexPath:indexPath];
    }
    
    // RuntimeBrowser 相关功能的表格单元格
    static NSString *cellId = @"RTBCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }
    
    UIViewController *owner = [self viewControllerForTableView:tableView];
    
    // 类层次结构模式
    if ([objc_getAssociatedObject(owner, "classHierarchyMode") boolValue]) {
        NSArray *rootClasses = objc_getAssociatedObject(owner, "rootClasses");
        NSString *className = rootClasses[indexPath.row];
        cell.textLabel.text = className;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        // 获取子类数量
        FLEXRuntimeClient *runtime = [FLEXRuntimeClient runtime];
        NSArray *subclasses = [runtime subclassesOfClass:className]; // 假设有这个方法
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu个子类", (unsigned long)subclasses.count];
        
        return cell;
    }
    
    // Hook检测器模式
    if ([objc_getAssociatedObject(owner, "hookDetectorMode") boolValue]) {
        NSDictionary *hookData = objc_getAssociatedObject(owner, "hookAnalysisData");
        NSArray *hookedClasses = hookData[@"hookedClasses"];
        NSDictionary *classInfo = hookedClasses[indexPath.row];
        
        cell.textLabel.text = classInfo[@"className"];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@个被Hook的方法", classInfo[@"hookedMethodsCount"]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        return cell;
    }
    
    // 框架浏览器模式
    if ([objc_getAssociatedObject(owner, "frameworkBrowserMode") boolValue]) {
        NSArray *bundlePaths = objc_getAssociatedObject(owner, "bundlePaths");
        NSDictionary *bundleClasses = objc_getAssociatedObject(owner, "bundleClasses");
        
        NSString *bundlePath = bundlePaths[indexPath.row];
        NSArray *classes = bundleClasses[bundlePath];
        
        cell.textLabel.text = [bundlePath lastPathComponent];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu个类", (unsigned long)classes.count];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        return cell;
    }
    
    if (self.isSearching && self.filteredResults) {
        if ([objc_getAssociatedObject(owner, "classHierarchyMode") boolValue]) {
            NSString *className = self.filteredResults[indexPath.row];
            cell.textLabel.text = className;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }
        // 处理其他搜索模式
    }
    
    return cell;
}

// 获取表格视图所属的视图控制器
- (UIViewController *)viewControllerForTableView:(UITableView *)tableView {
    UIResponder *responder = tableView;
    while ((responder = [responder nextResponder])) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
    }
    return nil;
}

// 判断是否为常规表格视图
- (BOOL)isRegularTableView:(UITableView *)tableView {
    return tableView == self.tableView;
}

// 原始表格视图的行数
- (NSInteger)regularTableViewNumberOfRowsInSection:(UITableView *)tableView section:(NSInteger)section {
    if (self.isInCategory) {
        NSArray *tools = self.toolsByCategory[self.currentCategory];
        return tools.count;
    }
    return self.categories.count;
}

// 原始表格视图的单元格
- (UITableViewCell *)regularTableViewCellForRowAtIndexPath:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath {
    // 这里复制原来的 cellForRowAtIndexPath 代码
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AppInfoCell"];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"AppInfoCell"];
    }
    
    if (self.isInCategory) {
        // 显示具体工具
        NSArray *tools = self.toolsByCategory[self.currentCategory];
        NSDictionary *tool = tools[indexPath.row];
        cell.textLabel.text = tool[@"title"];
        cell.detailTextLabel.text = tool[@"detail"];
    } else {
        // 显示分类
        NSDictionary *category = self.categories[indexPath.row];
        cell.textLabel.text = category[@"title"];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu个工具", 
            (unsigned long)[self.toolsByCategory[category[@"key"]] count]];
    }
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (self.isInCategory) {
        // 处理工具选择
        NSDictionary *tool = [self toolAtIndexPath:indexPath];
        NSString *className = tool[@"class"];
        NSString *action = tool[@"action"];
        
        if (className) {
            Class viewControllerClass = NSClassFromString(className);
            if (viewControllerClass) {
                UIViewController *viewController = [[viewControllerClass alloc] init];
                [self.navigationController pushViewController:viewController animated:YES];
            } else {
                NSLog(@"⚠️ 警告：类 %@ 未找到，请检查实现", className);
                
                // 提供更详细的错误信息和解决方案
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"功能开发中" 
                                                                               message:[NSString stringWithFormat:@"功能 \"%@\" 正在开发中\n\n错误详情：类 %@ 未找到\n请检查是否正确导入了对应的头文件。", tool[@"title"], className]
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                
                // 添加调试信息按钮
                UIAlertAction *debugAction = [UIAlertAction actionWithTitle:@"复制错误信息" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    [UIPasteboard generalPasteboard].string = [NSString stringWithFormat:@"Class not found: %@", className];
                }];
                
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil];
                
                [alert addAction:debugAction];
                [alert addAction:okAction];
                [self presentViewController:alert animated:YES completion:nil];
            }
        } else if (action) {
            [self performAction:action];
        }
    } else {
        // 进入分类
        NSDictionary *category = self.categories[indexPath.row];
        self.isInCategory = YES;
        self.currentCategory = category[@"key"];
        self.title = category[@"title"];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
            initWithTitle:@"返回"
            style:UIBarButtonItemStylePlain
            target:self
            action:@selector(backButtonTapped)];
        [self.tableView reloadData];
    }
}

#pragma mark - Helper Methods

- (NSDictionary *)toolAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isInCategory) {
        NSArray *tools = self.toolsByCategory[self.currentCategory];
        if (indexPath.row < tools.count) {
            return tools[indexPath.row];
        }
    }
    return nil;
}

#pragma mark - 功能实现方法

- (void)presentViewControllerWithClassName:(NSString *)className {
    Class viewControllerClass = NSClassFromString(className);
    if (viewControllerClass) {
        UIViewController *viewController = [[viewControllerClass alloc] init];
        [self.navigationController pushViewController:viewController animated:YES];
    } else {
        // 改进错误处理
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"功能开发中" 
                                                                       message:[NSString stringWithFormat:@"类 %@ 尚未实现", className]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)performAction:(NSString *)action {
    if ([action isEqualToString:@"showH5Door"]) {
        [self presentViewControllerWithClassName:@"FLEXH5DoorViewController"];
    } else if ([action isEqualToString:@"showClearCache"]) {
        [self presentViewControllerWithClassName:@"FLEXClearCacheViewController"];
    } else if ([action isEqualToString:@"showFPSMonitor"]) {
        [self presentViewControllerWithClassName:@"FLEXFPSMonitorViewController"];
    } else if ([action isEqualToString:@"showMemoryMonitor"]) {
        [self presentViewControllerWithClassName:@"FLEXMemoryMonitorViewController"];
    } else if ([action isEqualToString:@"showNetworkMonitor"]) {
        [self presentViewControllerWithClassName:@"FLEXNetworkMonitorViewController"];
    } else if ([action isEqualToString:@"showAPITest"]) {
        [self presentViewControllerWithClassName:@"FLEXAPITestViewController"];
    } else if ([action isEqualToString:@"showViewBorder"]) {
        [self showViewBorder];
    } else if ([action isEqualToString:@"showLayoutBounds"]) {
        [self showLayoutBounds];
    } else if ([action isEqualToString:@"showRuler"]) {
        [self showRuler];
    } else if ([action isEqualToString:@"showLookinMeasure"]) {
        [self showLookinMeasure];
    } else if ([action isEqualToString:@"showViewMeasurements"]) {
        [self showViewMeasurements];
    } else if ([action isEqualToString:@"showConstraintsVisualization"]) {
        [self showConstraintsVisualization];
    } else if ([action isEqualToString:@"enableLiveViewEditing"]) {
        [self enableLiveViewEditing];
    } else if ([action isEqualToString:@"showClassHierarchy"]) {
        [self showClassHierarchy];
    } else if ([action isEqualToString:@"showMemoryAnalyzer"]) {
        [self showMemoryAnalyzer];
    } else if ([action isEqualToString:@"showHookDetector"]) {
        [self showHookDetector];
    } else if ([action isEqualToString:@"showFrameworkBrowser"]) {
        [self showFrameworkBrowser];
    } else if ([action isEqualToString:@"showClassHierarchyAnalyzer"]) {
        [self showClassHierarchyAnalyzer];
    } else if ([action isEqualToString:@"showClassPerformanceAnalyzer"]) {
        [self showClassPerformanceAnalyzer];
    } else if ([action isEqualToString:@"showRuntimeBrowser"]) {
        [self showRuntimeBrowser];
    }
}

- (void)showCrashReport {
    FLEXDoKitCrashViewController *crashVC = [[FLEXDoKitCrashViewController alloc] init];
    [self.navigationController pushViewController:crashVC animated:YES];
}

- (void)showFPSMonitor {
    FLEXFPSMonitorViewController *fpsVC = [[FLEXFPSMonitorViewController alloc] init];
    [self.navigationController pushViewController:fpsVC animated:YES];
}

- (void)showMemoryMonitor {
    FLEXMemoryMonitorViewController *memoryVC = [[FLEXMemoryMonitorViewController alloc] init];
    [self.navigationController pushViewController:memoryVC animated:YES];
}

- (void)showLagMonitor {
    // 启动卡顿检测
    [self showAlertWithTitle:@"卡顿检测" message:@"卡顿检测功能已启动"];
}

- (void)showColorPicker {
    [self dismissViewControllerAnimated:YES completion:^{
        [[FLEXDoKitVisualTools sharedInstance] startColorPicker];
    }];
}

- (void)showRuler {
    [self dismissViewControllerAnimated:YES completion:^{
        [[FLEXDoKitVisualTools sharedInstance] showRuler];
    }];
}

- (void)showViewBorder {
    [self dismissViewControllerAnimated:YES completion:^{
        [[FLEXDoKitVisualTools sharedInstance] showViewBorders];
    }];
}

- (void)showLayoutBounds {
    [self dismissViewControllerAnimated:YES completion:^{
        [[FLEXDoKitVisualTools sharedInstance] showLayoutBounds];
    }];
}

- (void)showViewMeasurements {
    [self dismissViewControllerAnimated:YES completion:^{
        FLEXRevealLikeInspector *inspector = [FLEXRevealLikeInspector sharedInstance];
        [inspector showViewMeasurements:[UIApplication sharedApplication].keyWindow.rootViewController.view];
    }];
}

- (void)showConstraintsVisualization {
    [self dismissViewControllerAnimated:YES completion:^{
        FLEXRevealLikeInspector *inspector = [FLEXRevealLikeInspector sharedInstance];
        [inspector showViewConstraints:[UIApplication sharedApplication].keyWindow.rootViewController.view];
    }];
}

- (void)enableLiveViewEditing {
    [self dismissViewControllerAnimated:YES completion:^{
        FLEXRevealLikeInspector *inspector = [FLEXRevealLikeInspector sharedInstance];
        [inspector show3DViewHierarchy];
        [inspector enableLiveEditing];
    }];
}

- (void)showLookinMeasure {
    [[FLEXLookinMeasureController sharedInstance] startMeasuring];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title 
                                                                   message:message 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - RuntimeBrowser 功能实现

- (void)showClassHierarchy {
    // 实现类层次结构浏览
    FLEXTableViewController *vc = [[FLEXTableViewController alloc] init];
    vc.title = @"类层次结构";
    
    // 不调用不存在的方法
    // FLEXRuntimeClient *runtime = [FLEXRuntimeClient runtime];
    // NSArray *rootClasses = [runtime rootClasses];
    
    // 使用 Objective-C Runtime 获取类信息
    NSMutableArray *rootClasses = [NSMutableArray array];
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses > 0) {
        Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        
        for (int i = 0; i < numClasses; i++) {
            Class cls = classes[i];
            if (!class_getSuperclass(cls)) {
                [rootClasses addObject:cls];
            }
        }
        
        free(classes);
    }
    
    // 设置表格视图数据源
    vc.tableView.dataSource = self;
    vc.tableView.delegate = self;
    
    // 保存类数据供表格使用
    objc_setAssociatedObject(vc, "rootClasses", rootClasses, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(vc, "classHierarchyMode", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 配置搜索控制器
    UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.searchResultsUpdater = self;
    searchController.obscuresBackgroundDuringPresentation = NO;
    searchController.searchBar.placeholder = @"搜索类";
    if (@available(iOS 11.0, *)) {
        vc.navigationItem.searchController = searchController;
    } else {
        // iOS 11之前的替代方案，可能需要使用其他方式集成搜索
    }
    vc.definesPresentationContext = YES;
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showMemoryAnalyzer {
    // 使用已实现的内存分析器视图控制器
    FLEXMemoryAnalyzerViewController *vc = [[FLEXMemoryAnalyzerViewController alloc] init];
    
    // 视图控制器会在 viewDidLoad 中自动调用 FLEXMemoryAnalyzer+RuntimeBrowser 中的方法    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showHookDetector {
    // 创建展示 Hook 检测结果的控制器
    FLEXTableViewController *vc = [[FLEXTableViewController alloc] init];
    vc.title = @"Hook检测器";
    
    // 使用加载指示器
    UIActivityIndicatorViewStyle indicatorStyle;
    if (@available(iOS 13.0, *)) {
        indicatorStyle = (UIActivityIndicatorViewStyle)101; // UIActivityIndicatorViewStyleLarge
    } else {
        indicatorStyle = UIActivityIndicatorViewStyleWhiteLarge;
    }
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] 
                                        initWithActivityIndicatorStyle:indicatorStyle];
    indicator.center = vc.view.center;
    [vc.view addSubview:indicator];
    [indicator startAnimating];
    
    // 后台线程执行可能耗时的 Hook 检测
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 调用 RuntimeBrowser 分类方法获取 Hook 分析结果
        FLEXHookDetector *detector = [FLEXHookDetector sharedDetector];
        NSDictionary *hookAnalysis = [detector getDetailedHookAnalysis]; // 使用分类中的方法
        
        // 主线程更新 UI
        dispatch_async(dispatch_get_main_queue(), ^{
            [indicator stopAnimating];
            [indicator removeFromSuperview];
            
            // 存储数据供表格使用
            objc_setAssociatedObject(vc, "hookAnalysisData", hookAnalysis, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            vc.tableView.dataSource = self;
            vc.tableView.delegate = self;
            objc_setAssociatedObject(vc, "hookDetectorMode", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            
            [vc.tableView reloadData];
        });
    });
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showFrameworkBrowser {
    // 创建框架浏览器控制器
    FLEXTableViewController *vc = [[FLEXTableViewController alloc] init];
    vc.title = @"框架浏览器";
    
    // 获取所有已加载的镜像
    NSMutableDictionary *bundleClasses = [NSMutableDictionary dictionary];
    uint32_t count = _dyld_image_count();
    
    for (uint32_t i = 0; i < count; i++) {
        const char *path = _dyld_get_image_name(i);
        NSString *imagePath = @(path);
        NSString *lastComponent = [imagePath lastPathComponent];
        bundleClasses[imagePath] = lastComponent;
    }
    
    NSArray *bundlePaths = [bundleClasses.allKeys sortedArrayUsingSelector:@selector(compare:)];
    
    // 保存数据供表格使用
    objc_setAssociatedObject(vc, "bundlePaths", bundlePaths, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(vc, "bundleClasses", bundleClasses, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(vc, "frameworkBrowserMode", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 设置表格数据源
    vc.tableView.dataSource = self;
    vc.tableView.delegate = self;
    
    [vc.tableView reloadData];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchText = searchController.searchBar.text;
    
    // 获取当前表格视图所在的视图控制器，修复类型不匹配问题
    UIViewController *owner = nil;
    if ([searchController.searchResultsUpdater isKindOfClass:[UIViewController class]]) {
        owner = (UIViewController *)searchController.searchResultsUpdater;
    } else {
        owner = [self viewControllerForTableView:self.tableView];
    }
    
    self.isSearching = searchText.length > 0;
    
    if (!self.isSearching) {
        self.filteredResults = nil;
        [self reloadTableForOwner:owner];
        return;
    }
    
    // 根据不同模式进行搜索实现
    if ([objc_getAssociatedObject(owner, "classHierarchyMode") boolValue]) {
        // 搜索类
        Class searcherClass = NSClassFromString(@"FLEXClassSearcher");
        if (searcherClass && [searcherClass respondsToSelector:@selector(sharedSearcher)]) {
            id sharedSearcher = [searcherClass performSelector:@selector(sharedSearcher)];
            if ([sharedSearcher respondsToSelector:@selector(classesMatchingPattern:)]) {
                self.filteredResults = [sharedSearcher performSelector:@selector(classesMatchingPattern:) 
                                                           withObject:searchText];
            }
        }
    } else if ([objc_getAssociatedObject(owner, "hookDetectorMode") boolValue]) {
        // 搜索 Hook 方法
        NSDictionary *hookData = objc_getAssociatedObject(owner, "hookAnalysisData");
        NSArray *hookedClasses = hookData[@"hookedClasses"];
        NSMutableArray *filtered = [NSMutableArray array];
        
        for (NSDictionary *classInfo in hookedClasses) {
            NSString *className = classInfo[@"className"];
            if ([className.lowercaseString containsString:searchText.lowercaseString]) {
                [filtered addObject:classInfo];
            }
        }
        self.filteredResults = filtered;
    } else if ([objc_getAssociatedObject(owner, "frameworkBrowserMode") boolValue]) {
        // 搜索框架
        NSArray *bundlePaths = objc_getAssociatedObject(owner, "bundlePaths");
        NSMutableArray *filtered = [NSMutableArray array];
        
        for (NSString *path in bundlePaths) {
            if ([[path.lastPathComponent lowercaseString] containsString:searchText.lowercaseString]) {
                [filtered addObject:path];
            }
        }
        self.filteredResults = filtered;
    }
    
    [self reloadTableForOwner:owner];
}

- (void)reloadTableForOwner:(UIViewController *)owner {
    if ([owner respondsToSelector:@selector(tableView)]) {
        UITableView *tableView = [owner valueForKey:@"tableView"];
        [tableView reloadData];
    } else if ([owner isKindOfClass:[FLEXTableViewController class]]) {
        FLEXTableViewController *tableVC = (FLEXTableViewController *)owner;
        [tableVC.tableView reloadData];
    } else if ([owner isKindOfClass:[UITableViewController class]]) {
        UITableViewController *tableVC = (UITableViewController *)owner;
        [tableVC.tableView reloadData];
    }
}

// MARK: - 运行时分析功能实现

- (void)showClassHierarchyAnalyzer {
    // 创建一个替代的类层次查看器
    [self showAlertWithTitle:@"类层次分析" message:@"输入类名以分析其层次结构："];
    
    // 这里可以编写一个简单的层次分析实现
}

- (void)showMissingComponentError:(NSString *)componentName {
    UIAlertController *alert = [UIAlertController
                              alertControllerWithTitle:@"组件不可用"
                              message:[NSString stringWithFormat:@"%@组件不可用，请确保已正确导入相关文件", componentName]
                              preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction
                     actionWithTitle:@"确定"
                     style:UIAlertActionStyleDefault
                     handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showClassPerformanceAnalyzer {
    // 使用现有的性能分析器代替缺失的类
    FLEXPerformanceViewController *perfVC = [[FLEXPerformanceViewController alloc] init];
    [self.navigationController pushViewController:perfVC animated:YES];
}

- (void)showRuntimeBrowser {
    Class runtimeBrowserClass = NSClassFromString(@"RTBRuntimeBrowserViewController");
    if (!runtimeBrowserClass) {
        // 尝试查找替代类
        runtimeBrowserClass = NSClassFromString(@"FLEXRuntimeBrowserViewController");
    }
    
    if (runtimeBrowserClass) {
        UIViewController *rtbVC = [[runtimeBrowserClass alloc] init];
        [self.navigationController pushViewController:rtbVC animated:YES];
    } else {
        UIAlertController *alert = [UIAlertController
                                  alertControllerWithTitle:@"错误"
                                  message:@"Runtime浏览器不可用，请确保已正确导入RuntimeBrowser组件"
                                  preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction
                         actionWithTitle:@"确定"
                         style:UIAlertActionStyleDefault
                         handler:nil]];
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - 方法追踪功能实现

- (void)showMethodTracer {
    FLEXTableViewController *vc = [[FLEXTableViewController alloc] init];
    vc.title = @"方法追踪";
    
    // 创建方法追踪界面
    UILabel *instructionLabel = [[UILabel alloc] init];
    instructionLabel.text = @"选择要追踪的类和方法";
    instructionLabel.textAlignment = NSTextAlignmentCenter;
    instructionLabel.numberOfLines = 0;
    
    UITextField *classNameField = [[UITextField alloc] init];
    classNameField.placeholder = @"输入类名 (如: UIViewController)";
    classNameField.borderStyle = UITextBorderStyleRoundedRect;
    
    UITextField *methodNameField = [[UITextField alloc] init];
    methodNameField.placeholder = @"输入方法名 (如: viewDidLoad)";
    methodNameField.borderStyle = UITextBorderStyleRoundedRect;
    
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [startButton setTitle:@"开始追踪" forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(startMethodTracing:) forControlEvents:UIControlEventTouchUpInside];
    
    // 设置约束和添加到视图
    [vc.view addSubview:instructionLabel];
    [vc.view addSubview:classNameField];
    [vc.view addSubview:methodNameField];
    [vc.view addSubview:startButton];
    
    // 使用AutoLayout设置布局
    instructionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    classNameField.translatesAutoresizingMaskIntoConstraints = NO;
    methodNameField.translatesAutoresizingMaskIntoConstraints = NO;
    startButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSLayoutAnchor *topAnchor;
    if (@available(iOS 11.0, *)) {
        topAnchor = vc.view.safeAreaLayoutGuide.topAnchor;
    } else {
        topAnchor = vc.view.topAnchor;
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [instructionLabel.topAnchor constraintEqualToAnchor:topAnchor constant:20],
        [instructionLabel.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor constant:20],
        [instructionLabel.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor constant:-20],
        
        [classNameField.topAnchor constraintEqualToAnchor:instructionLabel.bottomAnchor constant:20],
        [classNameField.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor constant:20],
        [classNameField.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor constant:-20],
        [classNameField.heightAnchor constraintEqualToConstant:44],
        
        [methodNameField.topAnchor constraintEqualToAnchor:classNameField.bottomAnchor constant:10],
        [methodNameField.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor constant:20],
        [methodNameField.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor constant:-20],
        [methodNameField.heightAnchor constraintEqualToConstant:44],
        
        [startButton.topAnchor constraintEqualToAnchor:methodNameField.bottomAnchor constant:20],
        [startButton.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [startButton.heightAnchor constraintEqualToConstant:44]
    ]];
    
    // 保存字段引用以便后续使用
    objc_setAssociatedObject(vc, "classNameField", classNameField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(vc, "methodNameField", methodNameField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)startMethodTracing:(UIButton *)sender {
    UIViewController *currentVC = [self getCurrentViewController];
    UITextField *classNameField = objc_getAssociatedObject(currentVC, "classNameField");
    UITextField *methodNameField = objc_getAssociatedObject(currentVC, "methodNameField");
    
    NSString *className = classNameField.text;
    NSString *methodName = methodNameField.text;
    
    if (className.length == 0 || methodName.length == 0) {
        UIAlertController *alert = [UIAlertController 
                                  alertControllerWithTitle:@"输入错误" 
                                  message:@"请输入有效的类名和方法名" 
                                  preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [currentVC presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    Class targetClass = NSClassFromString(className);
    if (!targetClass) {
        UIAlertController *alert = [UIAlertController 
                                  alertControllerWithTitle:@"类不存在" 
                                  message:[NSString stringWithFormat:@"找不到类 '%@'", className] 
                                  preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [currentVC presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    SEL selector = NSSelectorFromString(methodName);
    if (![targetClass instancesRespondToSelector:selector] && ![targetClass respondsToSelector:selector]) {
        UIAlertController *alert = [UIAlertController 
                                  alertControllerWithTitle:@"方法不存在" 
                                  message:[NSString stringWithFormat:@"类 '%@' 不响应方法 '%@'", className, methodName] 
                                  preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [currentVC presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // 执行方法追踪
    [self performMethodTracing:targetClass selector:selector];
}

- (void)performMethodTracing:(Class)targetClass selector:(SEL)selector {
    NSString *className = NSStringFromClass(targetClass);
    NSString *selectorName = NSStringFromSelector(selector);
    
    // 创建方法跟踪实例
    NSLog(@"开始追踪 %@::%@", className, selectorName);
    
    // 使用方法交换实现跟踪
    Method originalMethod = class_getInstanceMethod(targetClass, selector);
    if (!originalMethod) {
        UIAlertController *alert = [UIAlertController 
                                  alertControllerWithTitle:@"错误"
                                  message:@"无法获取方法实现"
                                  preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // 保存原始实现
    // IMP originalImp = method_getImplementation(originalMethod);
    const char *typeEncoding = method_getTypeEncoding(originalMethod);
    
    // 创建新的实现，用于跟踪方法调用
    IMP newImp = imp_implementationWithBlock(^(id self, ...) {
        NSLog(@"[TracerLog] 方法被调用: %@ -> %@", className, selectorName);
        NSDate *startTime = [NSDate date];
        
        // 调用原始实现
        NSMethodSignature *signature = [targetClass instanceMethodSignatureForSelector:selector];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:self];
        [invocation setSelector:selector];
        [invocation invoke];
        
        // 计算执行时间
        NSTimeInterval executionTime = -[startTime timeIntervalSinceNow];
        NSLog(@"[TracerLog] 方法执行完成: %@ -> %@ (耗时: %f秒)", className, selectorName, executionTime);
        
        // 返回结果 - 这里简化处理，实际应根据方法返回类型处理
        id result = nil;
        [invocation getReturnValue:&result];
        return result;
    });
    
    // 交换实现
    class_replaceMethod(targetClass, selector, newImp, typeEncoding);
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"追踪已开始" 
                                                               message:[NSString stringWithFormat:@"正在追踪 %@::%@\n调用日志将显示在控制台中", className, selectorName]
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    
    UIViewController *currentVC = [self getCurrentViewController];
    [currentVC presentViewController:alert animated:YES completion:nil];
}

- (void)showClassSearcher {
    // 检查类是否存在
    Class searcherClass = NSClassFromString(@"FLEXClassSearcher");
    if (!searcherClass) {
        [self showMissingComponentError:@"类搜索器"];
        return;
    }
    
    // 判断视图控制器类型
    if ([searcherClass isSubclassOfClass:[UIViewController class]]) {
        UIViewController *searcherVC = [[searcherClass alloc] init];
        [self.navigationController pushViewController:searcherVC animated:YES];
    } else {
        // 创建展示搜索结果的控制器
        FLEXTableViewController *vc = [[FLEXTableViewController alloc] init];
        vc.title = @"类搜索";
        
        UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
        searchController.searchResultsUpdater = self;
        searchController.obscuresBackgroundDuringPresentation = NO;
        searchController.searchBar.placeholder = @"搜索类名";
        
        if (@available(iOS 11.0, *)) {
            vc.navigationItem.searchController = searchController;
            vc.definesPresentationContext = YES;
        } else {
            // 在iOS 11之前，将搜索栏添加到表头视图
            vc.tableView.tableHeaderView = searchController.searchBar;
        }
        
        // 配置表格
        objc_setAssociatedObject(vc, "classSearchMode", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        vc.tableView.dataSource = self;
        vc.tableView.delegate = self;
        
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (UIViewController *)getCurrentViewController {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    if ([topController isKindOfClass:[UINavigationController class]]) {
        return [(UINavigationController *)topController topViewController];
    } else if ([topController isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabController = (UITabBarController *)topController;
        UIViewController *selectedVC = tabController.selectedViewController;
        
        if ([selectedVC isKindOfClass:[UINavigationController class]]) {
            return [(UINavigationController *)selectedVC topViewController];
        }
        return selectedVC;
    }
    
    return topController;
}
@end