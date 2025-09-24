#import "FLEXDoKitLogViewController.h"
#import "FLEXDoKitLogViewer.h"
#import "FLEXCompatibility.h"

@interface FLEXDoKitLogViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UISegmentedControl *logLevelSegmentedControl;
@property (nonatomic, strong) UISearchBar *searchBar;
// 修改属性名，避免与父类的readonly属性冲突
@property (nonatomic, strong) UITableView *logTableView;
@property (nonatomic, strong) NSArray<FLEXDoKitLogEntry *> *displayedLogEntries;
@property (nonatomic, strong) NSArray<FLEXDoKitLogEntry *> *filteredLogEntries;
@property (nonatomic, copy) NSString *searchText;
@property (nonatomic, assign) FLEXDoKitLogLevel selectedLogLevel;
@end

@implementation FLEXDoKitLogViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"日志查看器";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupUI];
    [self setupNotifications];
    
    // 初始状态
    self.selectedLogLevel = FLEXDoKitLogLevelDebug; // 显示所有级别
    self.searchText = nil;
    
    [self refreshLogs];
}

- (void)setupUI {
    // 创建日志级别分段控制器
    self.logLevelSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"错误", @"警告", @"信息", @"调试", @"全部"]];
    self.logLevelSegmentedControl.selectedSegmentIndex = 4; // 默认选择"全部"
    [self.logLevelSegmentedControl addTarget:self action:@selector(logLevelChanged:) forControlEvents:UIControlEventValueChanged];
    self.logLevelSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 创建搜索栏
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索日志";
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 创建表格视图 - 修改为使用logTableView属性
    self.logTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.logTableView.dataSource = self;
    self.logTableView.delegate = self;
    self.logTableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 注册单元格 - 修改为使用logTableView
    [self.logTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"LogCell"];
    
    // 添加到视图
    [self.view addSubview:self.logLevelSegmentedControl];
    [self.view addSubview:self.searchBar];
    [self.view addSubview:self.logTableView];
    
    // 设置布局约束 - 更新所有约束中的tableView引用
    [NSLayoutConstraint activateConstraints:@[
        [self.logLevelSegmentedControl.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self) constant:8],
        [self.logLevelSegmentedControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.logLevelSegmentedControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        
        [self.searchBar.topAnchor constraintEqualToAnchor:self.logLevelSegmentedControl.bottomAnchor constant:8],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        
        [self.logTableView.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [self.logTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.logTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.logTableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    // 添加工具栏按钮
    UIBarButtonItem *clearButton = [[UIBarButtonItem alloc] initWithTitle:@"清除"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(clearLogs)];
    
    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithImage:[FLEXCompatibility systemImageNamed:@"gear" fallbackImageNamed:@"settings_icon"]
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(showSettings)];
    
    UIBarButtonItem *shareButton = [[UIBarButtonItem alloc] initWithImage:[FLEXCompatibility systemImageNamed:@"square.and.arrow.up" fallbackImageNamed:@"share_icon"]
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(shareLogs)];
    
    self.navigationItem.rightBarButtonItems = @[settingsButton, clearButton, shareButton];
}

- (void)setupNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(logEntryAdded:)
                                                 name:@"FLEXDoKitLogEntryAdded"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(logsCleared:)
                                                 name:@"FLEXDoKitLogCleared"
                                               object:nil];
}

#pragma mark - Actions

- (void)logLevelChanged:(UISegmentedControl *)sender {
    // 更新选中的日志级别
    switch (sender.selectedSegmentIndex) {
        case 0:
            self.selectedLogLevel = FLEXDoKitLogLevelError;
            break;
        case 1:
            self.selectedLogLevel = FLEXDoKitLogLevelWarning;
            break;
        case 2:
            self.selectedLogLevel = FLEXDoKitLogLevelInfo;
            break;
        case 3:
            self.selectedLogLevel = FLEXDoKitLogLevelDebug;
            break;
        case 4:
            self.selectedLogLevel = 999; // 表示显示全部
            break;
        default:
            self.selectedLogLevel = 999;
            break;
    }
    
    [self refreshLogs];
}

- (void)refreshLogs {
    // 获取所有日志
    NSArray<FLEXDoKitLogEntry *> *allLogs = [[FLEXDoKitLogViewer sharedViewer] logEntries];
    
    // 按照级别过滤
    if (self.selectedLogLevel != 999) {
        // 只显示小于等于所选级别的日志
        self.filteredLogEntries = [allLogs filteredArrayUsingPredicate:
                                  [NSPredicate predicateWithBlock:^BOOL(FLEXDoKitLogEntry *entry, NSDictionary *bindings) {
            return entry.level <= self.selectedLogLevel;
        }]];
    } else {
        self.filteredLogEntries = allLogs;
    }
    
    // 处理搜索
    if (self.searchText.length > 0) {
        self.displayedLogEntries = [self.filteredLogEntries filteredArrayUsingPredicate:
                                   [NSPredicate predicateWithFormat:@"message CONTAINS[cd] %@ OR tag CONTAINS[cd] %@", 
                                    self.searchText, self.searchText]];
    } else {
        self.displayedLogEntries = self.filteredLogEntries;
    }
    
    // 刷新表格
    [self.logTableView reloadData];
    
    // 如果有内容，滚动到底部
    if (self.displayedLogEntries.count > 0) {
        [self.logTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:self.displayedLogEntries.count - 1 inSection:0]
                               atScrollPosition:UITableViewScrollPositionBottom
                                       animated:NO];
    }
}

- (void)clearLogs {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清除所有日志"
                                                                   message:@"确定要清除所有日志记录吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"清除"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [[FLEXDoKitLogViewer sharedViewer] clearLogs];
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"日志设置"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *filterAction = [UIAlertAction actionWithTitle:@"过滤设置"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
        [self showFilterSettings];
    }];
    
    UIAlertAction *displayAction = [UIAlertAction actionWithTitle:@"显示设置"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self showDisplaySettings];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    [alert addAction:filterAction];
    [alert addAction:displayAction];
    [alert addAction:cancelAction];
    
    // 针对 iPad 的特别处理
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
        alert.popoverPresentationController.permittedArrowDirections = 0;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showFilterSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"日志过滤设置"
                                                                   message:@"按标签过滤日志"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"输入标签名称（留空显示全部）";
    }];
    
    UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"应用"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
        NSString *tagFilter = alert.textFields.firstObject.text;
        if (tagFilter.length > 0) {
            self.searchText = tagFilter;
        } else {
            self.searchText = nil;
        }
        [self refreshLogs];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    [alert addAction:saveAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showDisplaySettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"显示设置"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *timestampAction = [UIAlertAction actionWithTitle:@"显示/隐藏时间戳"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
        // 切换时间戳显示设置
        BOOL showTimestamp = ![[NSUserDefaults standardUserDefaults] boolForKey:@"FLEXDoKitLogShowTimestamp"];
        [[NSUserDefaults standardUserDefaults] setBool:showTimestamp forKey:@"FLEXDoKitLogShowTimestamp"];
        [self.logTableView reloadData];
    }];
    
    UIAlertAction *tagAction = [UIAlertAction actionWithTitle:@"显示/隐藏标签"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *action) {
        // 切换标签显示设置
        BOOL showTag = ![[NSUserDefaults standardUserDefaults] boolForKey:@"FLEXDoKitLogShowTag"];
        [[NSUserDefaults standardUserDefaults] setBool:showTag forKey:@"FLEXDoKitLogShowTag"];
        [self.logTableView reloadData];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    [alert addAction:timestampAction];
    [alert addAction:tagAction];
    [alert addAction:cancelAction];
    
    // 针对 iPad 的特别处理
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
        alert.popoverPresentationController.permittedArrowDirections = 0;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)shareLogs {
    NSMutableString *logText = [NSMutableString string];
    
    for (FLEXDoKitLogEntry *entry in self.displayedLogEntries) {
        [logText appendFormat:@"%@\n", entry.description];
    }
    
    if (logText.length == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"没有日志"
                                                                      message:@"当前没有可分享的日志"
                                                               preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[logText]
                                                                            applicationActivities:nil];
    
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
    }
    
    [self presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - Notifications

- (void)logEntryAdded:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshLogs];
    });
}

- (void)logsCleared:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshLogs];
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.displayedLogEntries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LogCell" forIndexPath:indexPath];
    
    FLEXDoKitLogEntry *entry = self.displayedLogEntries[indexPath.row];
    
    // 显示选项
    BOOL showTimestamp = [[NSUserDefaults standardUserDefaults] boolForKey:@"FLEXDoKitLogShowTimestamp"];
    BOOL showTag = [[NSUserDefaults standardUserDefaults] boolForKey:@"FLEXDoKitLogShowTag"];
    
    // 格式化日志
    NSMutableString *logMessage = [NSMutableString string];
    
    if (showTimestamp) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"HH:mm:ss.SSS";
        NSString *timeString = [formatter stringFromDate:entry.timestamp];
        [logMessage appendFormat:@"[%@] ", timeString];
    }
    
    [logMessage appendFormat:@"[%@] ", [entry levelString]];
    
    if (showTag) {
        [logMessage appendFormat:@"[%@] ", entry.tag];
    }
    
    [logMessage appendString:entry.message];
    
    cell.textLabel.text = logMessage;
    cell.textLabel.numberOfLines = 0;
    
    // 根据日志级别设置颜色
    switch (entry.level) {
        case FLEXDoKitLogLevelError:
            cell.textLabel.textColor = FLEXSystemRedColor;
            break;
        case FLEXDoKitLogLevelWarning:
            cell.textLabel.textColor = FLEXSystemOrangeColor;
            break;
        case FLEXDoKitLogLevelInfo:
            cell.textLabel.textColor = FLEXLabelColor;
            break;
        case FLEXDoKitLogLevelDebug:
            cell.textLabel.textColor = [UIColor grayColor];
            break;
        default:
            cell.textLabel.textColor = FLEXLabelColor;
            break;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // 显示日志详情
    FLEXDoKitLogEntry *entry = self.displayedLogEntries[indexPath.row];
    
    UIViewController *detailVC = [[UIViewController alloc] init];
    detailVC.title = @"日志详情";
    detailVC.view.backgroundColor = FLEXSystemBackgroundColor;
    
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [detailVC.view addSubview:scrollView];
    
    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 16;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:stackView];
    
    // 添加各种信息
    [self addDetailLabel:@"时间" value:[self formatDate:entry.timestamp] toStackView:stackView];
    [self addDetailLabel:@"级别" value:[entry levelString] toStackView:stackView];
    [self addDetailLabel:@"标签" value:entry.tag toStackView:stackView];
    [self addDetailLabel:@"消息" value:entry.message toStackView:stackView];
    
    if (entry.fileName) {
        [self addDetailLabel:@"文件" value:entry.fileName toStackView:stackView];
    }
    
    if (entry.lineNumber) {
        [self addDetailLabel:@"行号" value:[NSString stringWithFormat:@"%@", entry.lineNumber] toStackView:stackView];
    }
    
    if (entry.functionName) {
        [self addDetailLabel:@"函数" value:entry.functionName toStackView:stackView];
    }
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(detailVC)],
        [scrollView.leadingAnchor constraintEqualToAnchor:detailVC.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:detailVC.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:detailVC.view.bottomAnchor],
        
        [stackView.topAnchor constraintEqualToAnchor:scrollView.topAnchor constant:16],
        [stackView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor constant:16],
        [stackView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor constant:-16],
        [stackView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:-16],
        [stackView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor constant:-32]
    ]];
    
    // 添加分享按钮
    UIBarButtonItem *shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                                 target:self
                                                                                 action:@selector(shareLogEntry:)];
    shareButton.tag = indexPath.row; // 存储索引
    detailVC.navigationItem.rightBarButtonItem = shareButton;
    
    [self.navigationController pushViewController:detailVC animated:YES];
}

- (void)addDetailLabel:(NSString *)title value:(NSString *)value toStackView:(UIStackView *)stackView {
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [stackView addArrangedSubview:titleLabel];
    
    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.text = value;
    valueLabel.numberOfLines = 0;
    valueLabel.font = [UIFont systemFontOfSize:14];
    [stackView addArrangedSubview:valueLabel];
    
    UIView *separator = [[UIView alloc] init];
    separator.backgroundColor = [UIColor lightGrayColor];
    [separator.heightAnchor constraintEqualToConstant:1.0].active = YES;
    [stackView addArrangedSubview:separator];
}

- (NSString *)formatDate:(NSDate *)date {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    return [formatter stringFromDate:date];
}

- (void)shareLogEntry:(UIBarButtonItem *)sender {
    NSInteger index = sender.tag;
    if (index < self.displayedLogEntries.count) {
        FLEXDoKitLogEntry *entry = self.displayedLogEntries[index];
        NSString *shareText = [NSString stringWithFormat:@"日志详情:\n\n时间: %@\n级别: %@\n标签: %@\n消息: %@\n文件: %@\n行号: %@\n函数: %@",
                             [self formatDate:entry.timestamp],
                             [entry levelString],
                             entry.tag,
                             entry.message,
                             entry.fileName ?: @"未知",
                             entry.lineNumber ?: @"未知",
                             entry.functionName ?: @"未知"];
        
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[shareText]
                                                                                applicationActivities:nil];
        
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            activityVC.popoverPresentationController.barButtonItem = sender;
        }
        
        [self presentViewController:activityVC animated:YES completion:nil];
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.searchText = searchText.length > 0 ? searchText : nil;
    [self refreshLogs];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = nil;
    self.searchText = nil;
    [searchBar resignFirstResponder];
    [self refreshLogs];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 添加缺失的 super dealloc 调用
    [super dealloc];
}

@end