#import "RTBHookDetectorViewController.h"
#import "FLEXHookDetector.h"

@interface RTBHookDetectorViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *hookResults;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UIBarButtonItem *scanButton;

@end

@implementation RTBHookDetectorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Hook检测器";
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 设置UI
    [self setupUI];
    
    // 自动开始扫描
    [self startScan];
}

- (void)setupUI {
    // 创建表格视图
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    
    // 注册单元格
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"HookCell"];
    
    // 创建加载指示器
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingIndicator.center = self.view.center;
    self.loadingIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.loadingIndicator];
    
    // 创建扫描按钮
    self.scanButton = [[UIBarButtonItem alloc] initWithTitle:@"扫描" 
                                                       style:UIBarButtonItemStylePlain 
                                                      target:self 
                                                      action:@selector(startScan)];
    self.navigationItem.rightBarButtonItem = self.scanButton;
}

- (void)startScan {
    // 显示加载指示器
    [self.loadingIndicator startAnimating];
    self.scanButton.enabled = NO;
    
    // 在后台线程执行扫描
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 执行扫描操作
        NSArray *results = [self getHookDetectionResults];
        
        // 更新UI必须在主线程
        dispatch_async(dispatch_get_main_queue(), ^{
            self.hookResults = results;
            [self.tableView reloadData];
            [self.loadingIndicator stopAnimating];
            self.scanButton.enabled = YES;
        });
    });
}

- (NSArray *)getHookDetectionResults {
    NSMutableArray *results = [NSMutableArray array];
    
    // 尝试使用FLEXHookDetector类获取结果
    @try {
        if (NSClassFromString(@"FLEXHookDetector")) {
            id detector = [NSClassFromString(@"FLEXHookDetector") performSelector:@selector(sharedDetector)];
            if ([detector respondsToSelector:@selector(getAllHookedMethods)]) {
                NSArray *hookedMethods = [detector performSelector:@selector(getAllHookedMethods)];
                [results addObjectsFromArray:hookedMethods ?: @[]];
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"获取hook方法时出错: %@", exception);
    }
    
    // 如果没有检测到结果，添加一个占位项
    if (results.count == 0) {
        [results addObject:@{@"message": @"未检测到任何Hook方法"}];
    }
    
    return results;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.hookResults.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"HookCell" forIndexPath:indexPath];
    
    id item = self.hookResults[indexPath.row];
    
    // 根据结果类型设置单元格
    if ([item isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)item;
        
        if (dict[@"message"]) {
            // 这是一个消息项
            cell.textLabel.text = dict[@"message"];
            cell.detailTextLabel.text = nil;
        } else if (dict[@"className"] && dict[@"methodName"]) {
            // 这是一个方法项
            cell.textLabel.text = [NSString stringWithFormat:@"%@ - %@", dict[@"className"], dict[@"methodName"]];
            cell.detailTextLabel.text = dict[@"hookType"] ?: @"Unknown Hook";
        } else {
            // 通用字典项
            cell.textLabel.text = [dict description];
            cell.detailTextLabel.text = nil;
        }
    } else {
        // 其他类型
        cell.textLabel.text = [item description];
        cell.detailTextLabel.text = nil;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    // 可以在这里添加更详细的hook信息展示
}

@end