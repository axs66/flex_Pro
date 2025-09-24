#import "FLEXDoKitNetworkViewController.h"
#import "FLEXDoKitNetworkMonitor.h"
#import "FLEXCompatibility.h"
#import "FLEXSyntaxHighlighter.h"
#import <objc/runtime.h>

// 修改接口定义，移除重复的属性声明
@interface FLEXDoKitNetworkViewController () <UITableViewDataSource, UITableViewDelegate>
// 只保留额外的私有属性
@property (nonatomic, strong) UITableView *networkTableView;
@end

@implementation FLEXDoKitNetworkViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"网络监控";
    
    [self setupUI];
    [self setupNotifications];
    
    // 初始化网络监控
    if (![[FLEXDoKitNetworkMonitor sharedInstance] isMonitoring]) {
        [[FLEXDoKitNetworkMonitor sharedInstance] startMonitoring];
    }
    
    // 添加清除和设置按钮
    UIBarButtonItem *clearButton = [[UIBarButtonItem alloc] initWithTitle:@"清除"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(clearLogs)];
    
    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithImage:[FLEXCompatibility systemImageNamed:@"gear" fallbackImageNamed:@"settings_icon"]
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(showSettings)];
    
    self.navigationItem.rightBarButtonItems = @[settingsButton, clearButton];
    
    // 加载初始数据
    [self refreshData];
}

- (void)setupUI {
    // 创建分段控制器
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"全部", @"成功", @"失败", @"慢请求"]];
    self.segmentedControl.selectedSegmentIndex = 0;
    [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 创建表格视图
    self.networkTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.networkTableView.delegate = self;
    self.networkTableView.dataSource = self;
    self.networkTableView.rowHeight = UITableViewAutomaticDimension;
    self.networkTableView.estimatedRowHeight = 80;
    
    // 布局
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.networkTableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.segmentedControl];
    [self.view addSubview:self.networkTableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.segmentedControl.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self) constant:8],
        [self.segmentedControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.segmentedControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        
        [self.networkTableView.topAnchor constraintEqualToAnchor:self.segmentedControl.bottomAnchor constant:8],
        [self.networkTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.networkTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.networkTableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkRequestRecorded:)
                                                 name:@"FLEXDoKitNetworkRequestRecorded"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkResponseRecorded:)
                                                 name:@"FLEXDoKitNetworkResponseRecorded"
                                               object:nil];
}

- (void)refreshData {
    NSArray *allRequests = [[FLEXDoKitNetworkMonitor sharedInstance] networkRequests];
    
    // 根据分段控制器过滤数据
    switch (self.segmentedControl.selectedSegmentIndex) {
        case 0: // 全部
            self.networkRequests = allRequests;
            break;
        case 1: // 成功
            self.networkRequests = [allRequests filteredArrayUsingPredicate:
                                   [NSPredicate predicateWithFormat:@"statusCode >= 200 AND statusCode < 300"]];
            break;
        case 2: // 失败
            self.networkRequests = [allRequests filteredArrayUsingPredicate:
                                   [NSPredicate predicateWithFormat:@"statusCode >= 400 OR error != nil"]];
            break;
        case 3: // 慢请求
            self.networkRequests = [allRequests filteredArrayUsingPredicate:
                                   [NSPredicate predicateWithFormat:@"duration > 2.0"]];
            break;
    }
    
    [self.networkTableView reloadData];
}

#pragma mark - Actions

- (void)segmentChanged:(UISegmentedControl *)sender {
    [self refreshData];
}

- (void)clearLogs {
    [[[FLEXDoKitNetworkMonitor sharedInstance] networkRequests] removeAllObjects];
    [self refreshData];
}

- (void)showSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"网络设置"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *mockAction = [UIAlertAction actionWithTitle:@"Mock数据管理"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
        [self showMockSettings];
    }];
    
    UIAlertAction *slowNetworkAction = [UIAlertAction actionWithTitle:@"弱网模拟"
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *action) {
        [self showSlowNetworkSettings];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    [alert addAction:mockAction];
    [alert addAction:slowNetworkAction];
    [alert addAction:cancelAction];
    
    // 针对 iPad 的特别处理
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
        alert.popoverPresentationController.permittedArrowDirections = 0;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showMockSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Mock数据管理"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *addAction = [UIAlertAction actionWithTitle:@"添加Mock规则"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        [self showAddMockRuleDialog];
    }];
    
    UIAlertAction *viewAction = [UIAlertAction actionWithTitle:@"查看当前Mock规则"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
        [self showMockRulesList];
    }];
    
    UIAlertAction *clearAction = [UIAlertAction actionWithTitle:@"清除所有Mock规则"
                                                         style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction *action) {
        [[FLEXDoKitNetworkMonitor sharedInstance] clearMockRules];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    [alert addAction:addAction];
    [alert addAction:viewAction];
    [alert addAction:clearAction];
    [alert addAction:cancelAction];
    
    // 针对 iPad 的特别处理
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
        alert.popoverPresentationController.permittedArrowDirections = 0;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAddMockRuleDialog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加Mock规则"
                                                                   message:@"输入URL和返回数据"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"URL (支持部分匹配)";
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"状态码 (默认200)";
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"返回数据 (JSON格式)";
    }];
    
    UIAlertAction *addAction = [UIAlertAction actionWithTitle:@"添加"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        NSString *url = alert.textFields[0].text;
        NSString *statusCode = alert.textFields[1].text;
        NSString *responseData = alert.textFields[2].text;
        
        if (url.length > 0 && responseData.length > 0) {
            NSDictionary *rule = @{
                @"url": url,
                @"statusCode": @([statusCode integerValue] ?: 200),
                @"responseData": responseData,
                @"headers": @{@"Content-Type": @"application/json"}
            };
            
            [[FLEXDoKitNetworkMonitor sharedInstance] addMockRule:rule];
        }
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    [alert addAction:addAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showMockRulesList {
    NSArray *mockRules = [[FLEXDoKitNetworkMonitor sharedInstance] mockRules];
    
    if (mockRules.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"没有Mock规则"
                                                                      message:@"当前没有配置任何Mock规则"
                                                               preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                          style:UIAlertActionStyleDefault
                                                        handler:nil];
        
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"当前Mock规则"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSDictionary *rule in mockRules) {
        NSString *ruleTitle = [NSString stringWithFormat:@"%@ (状态码: %@)", rule[@"url"], rule[@"statusCode"]];
        
        UIAlertAction *ruleAction = [UIAlertAction actionWithTitle:ruleTitle
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
            [self showMockRuleDetail:rule];
        }];
        
        [alert addAction:ruleAction];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"关闭"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    [alert addAction:cancelAction];
    
    // 针对 iPad 的特别处理
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
        alert.popoverPresentationController.permittedArrowDirections = 0;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showMockRuleDetail:(NSDictionary *)rule {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Mock规则详情"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    NSString *detailMessage = [NSString stringWithFormat:@"URL: %@\n状态码: %@\n返回数据: %@",
                              rule[@"url"],
                              rule[@"statusCode"],
                              rule[@"responseData"]];
    
    [alert setMessage:detailMessage];
    
    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除规则"
                                                          style:UIAlertActionStyleDestructive
                                                        handler:^(UIAlertAction *action) {
        [[FLEXDoKitNetworkMonitor sharedInstance] removeMockRule:rule];
    }];
    
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"关闭"
                                                         style:UIAlertActionStyleCancel
                                                       handler:nil];
    
    [alert addAction:deleteAction];
    [alert addAction:closeAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSlowNetworkSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"弱网模拟"
                                                                   message:@"设置网络延迟和错误率"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"延迟时间(秒)，0表示不延迟";
        textField.keyboardType = UIKeyboardTypeDecimalPad;
        textField.text = [NSString stringWithFormat:@"%.1f", [[FLEXDoKitNetworkMonitor sharedInstance] networkDelay]];
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"错误率(0-1)，0表示不出错";
        textField.keyboardType = UIKeyboardTypeDecimalPad;
        textField.text = [NSString stringWithFormat:@"%.1f", [[FLEXDoKitNetworkMonitor sharedInstance] errorRate]];
    }];
    
    UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"保存"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
        NSString *delayText = alert.textFields[0].text;
        NSString *errorRateText = alert.textFields[1].text;
        
        double delay = [delayText doubleValue];
        double errorRate = [errorRateText doubleValue];
        
        // 限制范围
        delay = MAX(0, MIN(delay, 10));  // 0-10秒
        errorRate = MAX(0, MIN(errorRate, 1));  // 0-1
        
        [[FLEXDoKitNetworkMonitor sharedInstance] setNetworkDelay:delay];
        [[FLEXDoKitNetworkMonitor sharedInstance] setErrorRate:errorRate];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    [alert addAction:saveAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Notifications

- (void)networkRequestRecorded:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshData];
    });
}

- (void)networkResponseRecorded:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshData];
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // 确保引用正确的表格视图
    if (tableView == self.networkTableView) {
        return self.networkRequests.count;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"NetworkCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }
    
    NSDictionary *request = self.networkRequests[indexPath.row];
    
    // 主标题：URL
    cell.textLabel.text = request[@"url"];
    cell.textLabel.numberOfLines = 0;
    
    // 副标题：方法、状态码、耗时
    NSMutableString *subtitle = [NSMutableString string];
    
    [subtitle appendFormat:@"%@ ", request[@"method"] ?: @"GET"];
    
    if (request[@"statusCode"]) {
        NSInteger statusCode = [request[@"statusCode"] integerValue];
        [subtitle appendFormat:@"%ld ", (long)statusCode];
        
        // 状态码颜色
        if (statusCode >= 200 && statusCode < 300) {
            cell.textLabel.textColor = FLEXSystemGreenColor;
        } else if (statusCode >= 400) {
            cell.textLabel.textColor = FLEXSystemRedColor;
        } else {
            cell.textLabel.textColor = FLEXSystemOrangeColor;
        }
    } else {
        cell.textLabel.textColor = FLEXLabelColor;
    }
    
    if (request[@"duration"]) {
        [subtitle appendFormat:@"%.2fs", [request[@"duration"] doubleValue]];
    }
    
    if (request[@"error"]) {
        [subtitle appendString:@" ❌"];
    }
    
    cell.detailTextLabel.text = subtitle;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *request = self.networkRequests[indexPath.row];
    [self showRequestDetail:request];
}

- (void)showRequestDetail:(NSDictionary *)request {
    UIViewController *detailController = [[UIViewController alloc] init];
    detailController.title = @"请求详情";
    
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [detailController.view addSubview:scrollView];
    
    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 16;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:stackView];
    
    // URL信息
    [self addDetailSection:@"URL" content:request[@"url"] toStackView:stackView];
    
    // 请求方法
    [self addDetailSection:@"方法" content:request[@"method"] ?: @"GET" toStackView:stackView];
    
    // 状态码
    if (request[@"statusCode"]) {
        NSString *statusText = [NSString stringWithFormat:@"%@", request[@"statusCode"]];
        [self addDetailSection:@"状态码" content:statusText toStackView:stackView];
    }
    
    // 耗时
    if (request[@"duration"]) {
        NSString *durationText = [NSString stringWithFormat:@"%.2f秒", [request[@"duration"] doubleValue]];
        [self addDetailSection:@"耗时" content:durationText toStackView:stackView];
    }
    
    // 请求头
    if (request[@"requestHeaders"]) {
        NSString *headersText = [self formatDictionary:request[@"requestHeaders"]];
        [self addDetailSection:@"请求头" content:headersText toStackView:stackView];
    }
    
    // 请求体
    if (request[@"requestBody"]) {
        NSString *requestBody = request[@"requestBody"];
        if (requestBody.length > 0) {
            NSAttributedString *highlightedBody = [FLEXSyntaxHighlighter highlightJSONString:requestBody];
            [self addDetailSection:@"请求体" attributedContent:highlightedBody toStackView:stackView];
        }
    }
    
    // 响应头
    if (request[@"responseHeaders"]) {
        NSString *headersText = [self formatDictionary:request[@"responseHeaders"]];
        [self addDetailSection:@"响应头" content:headersText toStackView:stackView];
    }
    
    // 响应体
    if (request[@"responseBody"]) {
        NSString *responseBody = request[@"responseBody"];
        if (responseBody.length > 0) {
            NSAttributedString *highlightedBody = [FLEXSyntaxHighlighter highlightJSONString:responseBody];
            [self addDetailSection:@"响应体" attributedContent:highlightedBody toStackView:stackView];
        }
    }
    
    // 错误信息
    if (request[@"error"]) {
        [self addDetailSection:@"错误" content:request[@"error"] toStackView:stackView];
    }
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(detailController)],
        [scrollView.leadingAnchor constraintEqualToAnchor:detailController.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:detailController.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:detailController.view.bottomAnchor],
        
        [stackView.topAnchor constraintEqualToAnchor:scrollView.topAnchor constant:16],
        [stackView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor constant:16],
        [stackView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor constant:-16],
        [stackView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:-16],
        [stackView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor constant:-32]
    ]];
    
    [self.navigationController pushViewController:detailController animated:YES];
}

- (void)addDetailSection:(NSString *)title content:(nullable NSString *)content toStackView:(UIStackView *)stackView {
    if (!content) {
        return;
    }
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.numberOfLines = 0;
    [stackView addArrangedSubview:titleLabel];
    
    UILabel *contentLabel = [[UILabel alloc] init];
    contentLabel.text = content;
    contentLabel.font = [UIFont systemFontOfSize:14];
    contentLabel.numberOfLines = 0;
    [stackView addArrangedSubview:contentLabel];
    
    [self addSeparator:stackView]; // 使用新方法添加分隔线
}

- (void)addDetailSection:(NSString *)title attributedContent:(nullable NSAttributedString *)content toStackView:(UIStackView *)stackView {
    if (!content) {
        return;
    }
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.numberOfLines = 0;
    [stackView addArrangedSubview:titleLabel];
    
    UILabel *contentLabel = [[UILabel alloc] init];
    contentLabel.attributedText = content;
    contentLabel.numberOfLines = 0;
    [stackView addArrangedSubview:contentLabel];
    
    [self addSeparator:stackView]; // 使用新方法添加分隔线
}

- (NSString *)formatDictionary:(NSDictionary *)dict {
    NSMutableString *result = [NSMutableString string];
    
    for (NSString *key in [dict.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        [result appendFormat:@"%@: %@\n", key, dict[key]];
    }
    
    return result;
}

// 修复约束语法错误 (在第551行附近)
- (void)addSeparator:(UIView *)container {
    UIView *separator = [[UIView alloc] init];
    separator.backgroundColor = [UIColor lightGrayColor];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:separator];
    
    [NSLayoutConstraint activateConstraints:@[
        [separator.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [separator.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [separator.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [separator.heightAnchor constraintEqualToConstant:1]
    ]];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 添加缺失的 super dealloc 调用
    [super dealloc];
}

@end