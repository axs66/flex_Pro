#import "FLEXDoKitViewController.h"
#import "FLEXCompatibility.h"
#import "FLEXDoKitLogViewer.h"
#import "FLEX-DoKit.h"

@interface FLEXDoKitViewController ()
@property (nonatomic, strong, readwrite) UITableView *tableView;
@property (nonatomic, strong, readwrite) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation FLEXDoKitViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    [self setupBasicUI];
}

- (void)setupBasicUI {
    // 设置活动指示器
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.activityIndicator.hidesWhenStopped = YES;
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.activityIndicator];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
    
    // 设置状态标签
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textColor = FLEXSystemGrayColor;
    self.statusLabel.hidden = YES;
    self.statusLabel.numberOfLines = 0;
    [self.view addSubview:self.statusLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.statusLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.activityIndicator.bottomAnchor constant:8],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20]
    ]];
}

- (void)addTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.backgroundColor = FLEXSystemBackgroundColor;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self)],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)addRefreshControl {
    if (!self.tableView) {
        [self addTableView];
    }
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.tableView addSubview:self.refreshControl];
}

- (void)addSearchController {
    if (!self.tableView) {
        [self addTableView];
    }
    
    UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.obscuresBackgroundDuringPresentation = NO;
    searchController.searchBar.placeholder = @"搜索";
    
    if (@available(iOS 11.0, *)) {
        self.navigationItem.searchController = searchController;
        self.navigationItem.hidesSearchBarWhenScrolling = NO;
    } else {
        self.tableView.tableHeaderView = searchController.searchBar;
    }
    
    self.definesPresentationContext = YES;
}

- (void)addCloseButton {
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                                                                 target:self 
                                                                                 action:@selector(close)];
    self.navigationItem.rightBarButtonItem = closeButton;
}

- (void)addSettingsButton {
    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithImage:[FLEXCompatibility systemImageNamed:@"gear" fallbackImageNamed:@"settings_icon"]
                                                                       style:UIBarButtonItemStylePlain 
                                                                      target:self 
                                                                      action:@selector(showSettings)];
    
    if (self.navigationItem.rightBarButtonItem) {
        self.navigationItem.rightBarButtonItems = @[self.navigationItem.rightBarButtonItem, settingsButton];
    } else {
        self.navigationItem.rightBarButtonItem = settingsButton;
    }
}

- (void)close {
    if (self.navigationController.presentingViewController) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)showSettings {
    // 子类重写此方法以显示特定设置
}

- (void)showLoading {
    [self.activityIndicator startAnimating];
    self.statusLabel.hidden = YES;
}

- (void)hideLoading {
    [self.activityIndicator stopAnimating];
}

- (void)showError:(NSString *)message {
    [self hideLoading];
    self.statusLabel.text = message;
    self.statusLabel.textColor = FLEXSystemRedColor;
    self.statusLabel.hidden = NO;
    
    // 记录到日志系统
    FLEXDoKitLogError(@"Error", @"%@", message);
}

- (void)showSuccess:(NSString *)message {
    [self hideLoading];
    self.statusLabel.text = message;
    self.statusLabel.textColor = FLEXSystemGreenColor;
    self.statusLabel.hidden = NO;
    
    // 隐藏成功消息
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([self.statusLabel.text isEqualToString:message]) {
            self.statusLabel.hidden = YES;
        }
    });
}

- (void)showWarning:(NSString *)message {
    [self hideLoading];
    self.statusLabel.text = message;
    self.statusLabel.textColor = FLEXSystemOrangeColor;
    self.statusLabel.hidden = NO;
}

@end