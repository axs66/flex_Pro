#import "RTBMemoryAnalyzerViewController.h"

@interface RTBMemoryAnalyzerViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *memoryInfo;
@end

@implementation RTBMemoryAnalyzerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"内存分析";
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    
    // 加载内存数据
    [self loadMemoryData];
}

- (void)loadMemoryData {
    // 这里应该调用实际的内存分析逻辑
    self.memoryInfo = @[
        @{@"title": @"总内存", @"value": @"1024 MB"},
        @{@"title": @"已用内存", @"value": @"512 MB"},
        @{@"title": @"可用内存", @"value": @"512 MB"}
    ];
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.memoryInfo.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"MemoryInfoCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
    }
    
    NSDictionary *info = self.memoryInfo[indexPath.row];
    cell.textLabel.text = info[@"title"];
    cell.detailTextLabel.text = info[@"value"];
    
    return cell;
}

@end