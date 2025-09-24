#import "RTBNetworkAnalyzerViewController.h"
#import "RTBNetworkAnalyzer.h"

@interface RTBNetworkAnalyzerViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *networkRequests;
@end

@implementation RTBNetworkAnalyzerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"网络分析器";
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    
    // 加载网络请求数据
    [self loadNetworkRequests];
    
    // 添加刷新控件
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(loadNetworkRequests) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = refreshControl;
}

- (void)loadNetworkRequests {
    // 如果有网络分析器实例，获取请求数据
    // 否则显示占位数据
    self.networkRequests = @[];
    [self.tableView reloadData];
    [self.tableView.refreshControl endRefreshing];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.networkRequests.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"NetworkRequestCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    // 设置网络请求信息
    cell.textLabel.text = @"示例请求";
    cell.detailTextLabel.text = @"URL: https://example.com";
    
    return cell;
}

@end