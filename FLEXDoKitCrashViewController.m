#import "FLEXDoKitCrashViewController.h"
#import "FLEXCompatibility.h"
#import "FLEXSyntaxHighlighter.h"
#import <execinfo.h>
#import <mach-o/dyld.h>
#import <signal.h>

@interface FLEXDoKitCrashViewController ()
@property (nonatomic, strong) FLEXDoKitCrashRecord *selectedRecord;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@end

@implementation FLEXDoKitCrashViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"崩溃记录";
    
    [self setupTableView];
    [self addRefreshControl];
    // 使用crashTableView
    [self.refreshControl addTarget:self action:@selector(refreshCrashRecords) forControlEvents:UIControlEventValueChanged];
    
    // 初始化活动指示器
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.activityIndicator.hidesWhenStopped = YES;
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.activityIndicator];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
    
    // 添加工具栏按钮
    UIBarButtonItem *clearButton = [[UIBarButtonItem alloc] 
                                   initWithTitle:@"清空" 
                                   style:UIBarButtonItemStylePlain
                                   target:self 
                                   action:@selector(promptToClearCrashRecords)];
    
    UIBarButtonItem *setupButton = [[UIBarButtonItem alloc] 
                                   initWithTitle:@"设置" 
                                   style:UIBarButtonItemStylePlain 
                                   target:self 
                                   action:@selector(showSettings)];
    
    self.navigationItem.rightBarButtonItems = @[clearButton, setupButton];
    
    // 安装崩溃处理器
    [self installCrashHandler];
    
    // 加载崩溃记录
    [self refreshCrashRecords];
}

- (void)setupTableView {
    self.crashTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.crashTableView.delegate = self;
    self.crashTableView.dataSource = self;
    self.crashTableView.backgroundColor = FLEXSystemBackgroundColor;
    self.crashTableView.estimatedRowHeight = 80;
    self.crashTableView.rowHeight = UITableViewAutomaticDimension;
    [self.crashTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"CrashCell"];
    
    self.crashTableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.crashTableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.crashTableView.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self)],
        [self.crashTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.crashTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.crashTableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)installCrashHandler {
    NSSetUncaughtExceptionHandler(&FLEXDoKitUncaughtExceptionHandler);
    
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_flags = SA_SIGINFO;
    action.sa_sigaction = &FLEXDoKitSignalHandler;
    
    // 注册信号处理器
    sigaction(SIGABRT, &action, NULL);
    sigaction(SIGILL, &action, NULL);
    sigaction(SIGSEGV, &action, NULL);
    sigaction(SIGFPE, &action, NULL);
    sigaction(SIGBUS, &action, NULL);
    sigaction(SIGPIPE, &action, NULL);
}

void FLEXDoKitUncaughtExceptionHandler(NSException *exception) {
    NSArray *callStack = [exception callStackSymbols] ?: @[];
    
    NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionary];
    deviceInfo[@"model"] = [[UIDevice currentDevice] model];
    deviceInfo[@"systemVersion"] = [[UIDevice currentDevice] systemVersion];
    deviceInfo[@"systemName"] = [[UIDevice currentDevice] systemName];
    
    NSMutableDictionary *appInfo = [NSMutableDictionary dictionary];
    NSBundle *mainBundle = [NSBundle mainBundle];
    appInfo[@"bundleIdentifier"] = [mainBundle bundleIdentifier];
    appInfo[@"version"] = [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    appInfo[@"build"] = [mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    
    FLEXDoKitCrashRecord *record = [FLEXDoKitCrashRecord recordWithException:exception additionalInfo:@{
        @"deviceInfo": deviceInfo,
        @"appInfo": appInfo,
        @"callStack": callStack  // 使用callStack变量
    }];
    
    // 保存崩溃记录
    NSMutableArray *records = [[FLEXDoKitCrashRecord loadRecordsFromDisk] mutableCopy] ?: [NSMutableArray array];
    [records addObject:[record toDictionary]];
    [FLEXDoKitCrashRecord saveRecordsToDisk:records];
}

void FLEXDoKitSignalHandler(int sig, siginfo_t *info, void *context) {
    NSMutableArray *callStack = [NSMutableArray array];
    
    // 获取调用栈
    void *backtraceFrames[128];
    int frameCount = backtrace(backtraceFrames, 128);
    char **symbols = backtrace_symbols(backtraceFrames, frameCount);
    
    if (symbols) {
        for (int i = 0; i < frameCount; i++) {
            [callStack addObject:[NSString stringWithUTF8String:symbols[i]]];
        }
        free(symbols);
    }
    
    NSString *signalName;
    switch (sig) {
        case SIGABRT: signalName = @"SIGABRT"; break;
        case SIGILL: signalName = @"SIGILL"; break;
        case SIGSEGV: signalName = @"SIGSEGV"; break;
        case SIGFPE: signalName = @"SIGFPE"; break;
        case SIGBUS: signalName = @"SIGBUS"; break;
        case SIGPIPE: signalName = @"SIGPIPE"; break;
        default: signalName = [NSString stringWithFormat:@"Signal %d", sig];
    }
    
    NSString *reason = [NSString stringWithFormat:@"Received signal: %@", signalName];
    
    NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionary];
    deviceInfo[@"model"] = [[UIDevice currentDevice] model];
    deviceInfo[@"systemVersion"] = [[UIDevice currentDevice] systemVersion];
    deviceInfo[@"systemName"] = [[UIDevice currentDevice] systemName];
    
    NSMutableDictionary *appInfo = [NSMutableDictionary dictionary];
    NSBundle *mainBundle = [NSBundle mainBundle];
    appInfo[@"bundleIdentifier"] = [mainBundle bundleIdentifier];
    appInfo[@"version"] = [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    appInfo[@"build"] = [mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    
    // 创建崩溃记录并保存
    NSMutableArray *records = [[FLEXDoKitCrashRecord loadRecordsFromDisk] mutableCopy] ?: [NSMutableArray array];
    
    NSDictionary *recordDict = @{
        @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"reason": reason,
        @"type": signalName,
        @"callStack": callStack,
        @"deviceInfo": deviceInfo,
        @"appInfo": appInfo
    };
    
    [records addObject:recordDict];
    [FLEXDoKitCrashRecord saveRecordsToDisk:records];
    
    // 恢复默认处理器以允许程序继续崩溃
    struct sigaction sa;
    sa.sa_handler = SIG_DFL;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(sig, &sa, NULL);
    raise(sig);
}

- (void)refreshCrashRecords {
    self.crashRecords = [FLEXDoKitCrashRecord allRecords];
    [self.crashTableView reloadData];
    [self.refreshControl endRefreshing];
    
    if (self.crashRecords.count == 0) {
        [self showWarning:@"没有崩溃记录"];
    } else {
        [self hideLoading];
    }
}

- (void)promptToClearCrashRecords {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认清空"
                                                                   message:@"确定要清空所有崩溃记录吗？此操作无法撤销。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self clearCrashRecords];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)clearCrashRecords {
    [FLEXDoKitCrashRecord clearAllRecords];
    [self refreshCrashRecords];
    [self showSuccess:@"已清空所有崩溃记录"];
}

- (void)showSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"崩溃捕获设置"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"模拟异常崩溃" 
                                              style:UIAlertActionStyleDefault 
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self simulateExceptionCrash];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"模拟信号崩溃" 
                                              style:UIAlertActionStyleDefault 
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self simulateSignalCrash];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)simulateExceptionCrash {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认模拟崩溃"
                                                                   message:@"这将导致应用崩溃，确定继续吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSArray *array = @[];
            id object = array[1]; // 越界访问触发崩溃
            NSLog(@"%@", object);
        });
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)simulateSignalCrash {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认模拟崩溃"
                                                                   message:@"这将导致应用崩溃，确定继续吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            int *nullPointer = NULL;
            *nullPointer = 42; // 空指针访问触发崩溃
        });
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showCrashDetail:(FLEXDoKitCrashRecord *)record {
    self.selectedRecord = record;
    
    UIViewController *detailViewController = [[UIViewController alloc] init];
    detailViewController.title = @"崩溃详情";
    
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [detailViewController.view addSubview:scrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(detailViewController)],
        [scrollView.leadingAnchor constraintEqualToAnchor:detailViewController.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:detailViewController.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:detailViewController.view.bottomAnchor]
    ]];
    
    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 16;
    stackView.layoutMargins = UIEdgeInsetsMake(16, 16, 16, 16);
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.layoutMarginsRelativeArrangement = YES;  // 修改属性名
    [scrollView addSubview:stackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [stackView.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [stackView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [stackView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [stackView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
        [stackView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor]
    ]];
    
    // 添加崩溃信息
    [self addInfoSection:@"崩溃时间" content:[self formattedDateFromDate:record.timestamp] toStackView:stackView];
    [self addInfoSection:@"崩溃类型" content:record.type toStackView:stackView];
    [self addInfoSection:@"崩溃原因" content:record.reason toStackView:stackView];
    
    // 添加设备信息
    NSMutableString *deviceInfoString = [NSMutableString string];
    [record.deviceInfo enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        [deviceInfoString appendFormat:@"%@: %@\n", key, obj];
    }];
    [self addInfoSection:@"设备信息" content:deviceInfoString toStackView:stackView];
    
    // 添加应用信息
    NSMutableString *appInfoString = [NSMutableString string];
    [record.appInfo enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        [appInfoString appendFormat:@"%@: %@\n", key, obj];
    }];
    [self addInfoSection:@"应用信息" content:appInfoString toStackView:stackView];
    
    // 添加调用栈信息
    NSMutableString *callStackString = [NSMutableString string];
    for (NSString *frame in record.callStack) {
        [callStackString appendFormat:@"%@\n", frame];
    }
    [self addInfoSection:@"调用栈" content:callStackString toStackView:stackView];
    
    [self.navigationController pushViewController:detailViewController animated:YES];
}

#pragma mark - Helper Methods

- (void)addInfoSection:(NSString *)title content:(NSString *)content toStackView:(UIStackView *)stackView {
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.text = title;
    
    UILabel *contentLabel = [[UILabel alloc] init];
    contentLabel.font = [UIFont systemFontOfSize:14];
    contentLabel.text = content;
    contentLabel.numberOfLines = 0;
    
    UIStackView *sectionStack = [[UIStackView alloc] init];
    sectionStack.axis = UILayoutConstraintAxisVertical;
    sectionStack.spacing = 4;
    
    [sectionStack addArrangedSubview:titleLabel];
    [sectionStack addArrangedSubview:contentLabel];
    
    UIView *separatorView = [[UIView alloc] init];
    separatorView.backgroundColor = [UIColor lightGrayColor];
    separatorView.translatesAutoresizingMaskIntoConstraints = NO;
    [separatorView.heightAnchor constraintEqualToConstant:1].active = YES;
    
    [stackView addArrangedSubview:sectionStack];
    [stackView addArrangedSubview:separatorView];
}

- (NSString *)formattedDateFromDate:(NSDate *)date {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    return [formatter stringFromDate:date];
}

- (void)showWarning:(NSString *)message {
    UILabel *label = [[UILabel alloc] init];
    label.text = message;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor grayColor];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:label];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)showSuccess:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        [self presentViewController:alert animated:YES completion:^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [alert dismissViewControllerAnimated:YES completion:nil];
            });
        }];
    });
}

- (void)hideLoading {
    // 停止所有加载指示
    [self.activityIndicator stopAnimating];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.crashRecords.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CrashCell" forIndexPath:indexPath];
    
    FLEXDoKitCrashRecord *record = self.crashRecords[indexPath.row];
    
    cell.textLabel.numberOfLines = 2;
    cell.textLabel.text = [NSString stringWithFormat:@"%@\n%@", 
                           [self formattedDateFromDate:record.timestamp],
                           record.reason];
    
    cell.detailTextLabel.text = record.type;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    FLEXDoKitCrashRecord *record = self.crashRecords[indexPath.row];
    [self showCrashDetail:record];
}

@end