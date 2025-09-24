#import "FLEXClassHierarchyViewController.h"
#import "FLEXClassPerformanceViewController.h"
#import <objc/runtime.h>

@interface FLEXClassPerformanceViewController () <UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISegmentedControl *segmentControl;
@property (nonatomic, strong) NSArray *largeClasses;
@property (nonatomic, strong) NSArray *classesWithManyMethods;
@property (nonatomic, strong) NSArray *performanceClasses;
@property (nonatomic, strong) NSArray *memoryClasses;
@property (nonatomic, assign) NSInteger viewMode; // 0: 大小, 1: 方法数量
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSArray *filteredClasses;
@property (nonatomic, assign) BOOL isSearching;
@property (nonatomic, strong) UIActivityIndicatorView *loader;

@end

@implementation FLEXClassPerformanceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"类性能分析";
    
    // 添加更多分段选项
    self.segmentControl = [[UISegmentedControl alloc] initWithItems:@[@"大小", @"方法数", @"性能", @"内存"]];
    self.segmentControl.selectedSegmentIndex = 0;
    self.viewMode = 0;
    [self.segmentControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = self.segmentControl;
    
    // 添加导出功能
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] 
        initWithBarButtonSystemItem:UIBarButtonSystemItemAction 
        target:self 
        action:@selector(exportAnalysisData)];
    
    // 设置加载指示器
    if (@available(iOS 13.0, *)) {
        self.loader = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    } else {
        self.loader = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    }
    self.loader.center = self.view.center;
    self.loader.hidesWhenStopped = YES;
    [self.view addSubview:self.loader];
    [self.loader startAnimating];
    
    // 设置表格视图
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.hidden = YES;
    [self.view addSubview:self.tableView];
    
    // 添加搜索控制器
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"按类名搜索";
    if (@available(iOS 11.0, *)) {
        self.navigationItem.searchController = self.searchController;
    } else {
        // iOS 11以下版本使用表头方式添加搜索控件
        self.tableView.tableHeaderView = self.searchController.searchBar;
    }
    
    // 加载分析数据
    [self performAnalysis];
}

- (void)performAnalysis {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 性能分析
        NSMutableArray *largeClassesArr = [NSMutableArray array];
        NSMutableArray *manyMethodsArr = [NSMutableArray array];
        NSMutableArray *performanceArr = [NSMutableArray array];
        NSMutableArray *memoryArr = [NSMutableArray array];
        
        unsigned int count = 0;
        Class *classes = objc_copyClassList(&count);
        
        NSMutableArray *allClasses = [NSMutableArray arrayWithCapacity:count];
        
        for (unsigned int i = 0; i < count; i++) {
            Class cls = classes[i];
            NSString *className = NSStringFromClass(cls);
            
            // 跳过系统私有类
            if ([className hasPrefix:@"_"] || [className hasPrefix:@"NS"] || [className hasPrefix:@"UI"]) {
                continue;
            }
            
            NSUInteger classSize = class_getInstanceSize(cls);
            NSUInteger methodCount = [self methodCountForClass:cls];
            NSUInteger propertyCount = [self propertyCountForClass:cls];
            NSUInteger protocolCount = [self protocolCountForClass:cls];
            
            // 计算复杂度得分
            NSUInteger complexityScore = methodCount * 2 + propertyCount + protocolCount;
            
            // 估算内存占用
            NSUInteger estimatedMemoryUsage = classSize + (methodCount * sizeof(void*));
            
            NSDictionary *classInfo = @{
                @"class": cls,
                @"className": className,
                @"size": @(classSize),
                @"methodCount": @(methodCount),
                @"propertyCount": @(propertyCount),
                @"protocolCount": @(protocolCount),
                @"complexityScore": @(complexityScore),
                @"estimatedMemoryUsage": @(estimatedMemoryUsage)
            };
            
            [allClasses addObject:classInfo];
        }
        
        free(classes);
        
        // 按不同标准排序
        [largeClassesArr addObjectsFromArray:[allClasses sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            return [obj2[@"size"] compare:obj1[@"size"]];
        }]];
        
        [manyMethodsArr addObjectsFromArray:[allClasses sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            return [obj2[@"methodCount"] compare:obj1[@"methodCount"]];
        }]];
        
        [performanceArr addObjectsFromArray:[allClasses sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            return [obj2[@"complexityScore"] compare:obj1[@"complexityScore"]];
        }]];
        
        [memoryArr addObjectsFromArray:[allClasses sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            return [obj2[@"estimatedMemoryUsage"] compare:obj1[@"estimatedMemoryUsage"]];
        }]];
        
        // 限制数量
        if (largeClassesArr.count > 200) {
            largeClassesArr = [NSMutableArray arrayWithArray:[largeClassesArr subarrayWithRange:NSMakeRange(0, 200)]];
        }
        
        if (manyMethodsArr.count > 200) {
            manyMethodsArr = [NSMutableArray arrayWithArray:[manyMethodsArr subarrayWithRange:NSMakeRange(0, 200)]];
        }
        
        if (performanceArr.count > 200) {
            performanceArr = [NSMutableArray arrayWithArray:[performanceArr subarrayWithRange:NSMakeRange(0, 200)]];
        }
        
        if (memoryArr.count > 200) {
            memoryArr = [NSMutableArray arrayWithArray:[memoryArr subarrayWithRange:NSMakeRange(0, 200)]];
        }
        
        self.largeClasses = largeClassesArr;
        self.classesWithManyMethods = manyMethodsArr;
        self.performanceClasses = performanceArr;
        self.memoryClasses = memoryArr;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.loader stopAnimating];
            self.tableView.hidden = NO;
            [self.tableView reloadData];
        });
    });
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    self.viewMode = sender.selectedSegmentIndex;
    [self.tableView reloadData];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchText = searchController.searchBar.text;
    
    if (searchText.length > 0) {
        self.isSearching = YES;
        
        NSArray *sourceArray = self.viewMode == 0 ? self.largeClasses : self.classesWithManyMethods;
        NSMutableArray *filtered = [NSMutableArray array];
        
        for (NSDictionary *classInfo in sourceArray) {
            NSString *className = classInfo[@"className"];
            if ([className localizedCaseInsensitiveContainsString:searchText]) {
                [filtered addObject:classInfo];
            }
        }
        
        self.filteredClasses = filtered;
    } else {
        self.isSearching = NO;
        self.filteredClasses = nil;
    }
    
    [self.tableView reloadData];
}

#pragma mark - UITableViewDelegate & UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.isSearching) {
        return self.filteredClasses.count;
    } else {
        return self.viewMode == 0 ? self.largeClasses.count : self.classesWithManyMethods.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"PerformanceCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    NSDictionary *classInfo;
    
    if (self.isSearching) {
        classInfo = self.filteredClasses[indexPath.row];
    } else if (self.viewMode == 0) {
        classInfo = self.largeClasses[indexPath.row];
    } else {
        classInfo = self.classesWithManyMethods[indexPath.row];
    }
    
    NSString *className = classInfo[@"className"];
    NSUInteger size = [classInfo[@"size"] unsignedIntegerValue];
    NSUInteger methodCount = [classInfo[@"methodCount"] unsignedIntegerValue];
    
    cell.textLabel.text = className;
    
    if (self.viewMode == 0) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"大小: %lu 字节 | 方法: %lu", 
                                     (unsigned long)size, (unsigned long)methodCount];
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"方法: %lu | 大小: %lu 字节", 
                                     (unsigned long)methodCount, (unsigned long)size];
    }
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *classInfo;
    
    if (self.isSearching) {
        classInfo = self.filteredClasses[indexPath.row];
    } else if (self.viewMode == 0) {
        classInfo = self.largeClasses[indexPath.row];
    } else {
        classInfo = self.classesWithManyMethods[indexPath.row];
    }
    
    NSString *className = classInfo[@"className"];
    Class classObj = classInfo[@"class"];  // 只保留一个类变量，确保名称一致
    
    // 创建详情视图控制器
    UIViewController *detailVC = nil;
    
    // 使用安全的方法创建视图控制器
    Class hierViewClass = NSClassFromString(@"FLEXClassHierarchyViewController");
    if (hierViewClass) {
        if ([hierViewClass instancesRespondToSelector:@selector(initWithClass:)]) {
            detailVC = [[hierViewClass alloc] initWithClass:classObj];
        } 
        else if ([hierViewClass instancesRespondToSelector:@selector(initWithClassName:)]) {
            detailVC = [[hierViewClass alloc] initWithClassName:className];
        }
        else {
            detailVC = [[hierViewClass alloc] init];
        }
    }
    
    if (!detailVC) {
        // 如果无法创建，则尝试使用对象浏览器
        Class explorerClass = NSClassFromString(@"FLEXObjectExplorerViewController");
        if (explorerClass && [explorerClass instancesRespondToSelector:@selector(initWithObject:)]) {
            // 使用直接方法调用代替performSelector
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wincompatible-pointer-types"
            detailVC = [[explorerClass alloc] initWithObject:classObj];
            #pragma clang diagnostic pop
        }
    }
    
    // 如果成功创建了视图控制器，则推入导航栈
    if (detailVC) {
        [self.navigationController pushViewController:detailVC animated:YES];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.isSearching) {
        return [NSString stringWithFormat:@"搜索结果 (%lu)", (unsigned long)self.filteredClasses.count];
    } else if (self.viewMode == 0) {
        return @"按实例大小排序的类 (前200)";
    } else {
        return @"按方法数量排序的类 (前200)";
    }
}

- (void)exportAnalysisData {
    NSArray *currentData = [self getCurrentData];
    
    NSMutableString *csvData = [NSMutableString stringWithString:@"类名,大小,方法数,属性数,协议数,复杂度,内存占用\n"];
    
    for (NSDictionary *classInfo in currentData) {
        [csvData appendFormat:@"%@,%@,%@,%@,%@,%@,%@\n",
            classInfo[@"className"],
            classInfo[@"size"],
            classInfo[@"methodCount"],
            classInfo[@"propertyCount"] ?: @"0",
            classInfo[@"protocolCount"] ?: @"0",
            classInfo[@"complexityScore"] ?: @"0",
            classInfo[@"estimatedMemoryUsage"] ?: @"0"
        ];
    }
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] 
        initWithActivityItems:@[csvData] 
        applicationActivities:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }
    
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (NSArray *)getCurrentData {
    switch (self.viewMode) {
        case 0: return self.largeClasses;
        case 1: return self.classesWithManyMethods;
        case 2: return self.performanceClasses;
        case 3: return self.memoryClasses;
        default: return self.largeClasses;
    }
}

- (NSUInteger)methodCountForClass:(Class)cls {
    unsigned int instanceMethodCount = 0;
    Method *instanceMethods = class_copyMethodList(cls, &instanceMethodCount);
    if (instanceMethods) free(instanceMethods);
    
    unsigned int classMethodCount = 0;
    Method *classMethods = class_copyMethodList(object_getClass(cls), &classMethodCount);
    if (classMethods) free(classMethods);
    
    return instanceMethodCount + classMethodCount;
}

- (NSUInteger)propertyCountForClass:(Class)cls {
    unsigned int count = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &count);
    if (properties) free(properties);
    return count;
}

- (NSUInteger)protocolCountForClass:(Class)cls {
    unsigned int count = 0;
    Protocol * __unsafe_unretained *protocols = class_copyProtocolList(cls, &count);
    if (protocols) free(protocols);
    return count;
}

@end