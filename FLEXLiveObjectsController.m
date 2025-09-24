//
//  FLEXLiveObjectsController.m
//  Flipboard
//
//  Created by Ryan Olson on 5/28/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXLiveObjectsController.h"
#import "FLEXObjectExplorerViewController.h"
#import "FLEXUtility.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXHeapEnumerator.h"
#import "FLEXCompatibility.h"
#import <objc/runtime.h>
#import <malloc/malloc.h>

@interface FLEXLiveObjectsController ()
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSArray<Class> *filteredClasses;
@property (nonatomic, assign) BOOL isSearching;
@end

@implementation FLEXLiveObjectsController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"活动对象";
        self.trackedClasses = [NSMutableArray array];
        self.classCounts = [NSMutableDictionary dictionary];
        self.filteredClasses = @[];
        
        // 设置搜索控制器
        self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
        self.searchController.searchResultsUpdater = (id<UISearchResultsUpdating>)self;
        self.searchController.obscuresBackgroundDuringPresentation = NO;
        self.searchController.searchBar.placeholder = @"搜索类名";
        self.searchController.searchBar.delegate = (id<UISearchBarDelegate>)self;
        
        if (@available(iOS 11.0, *)) {
            self.navigationItem.searchController = self.searchController;
            self.navigationItem.hidesSearchBarWhenScrolling = NO;
        } else {
            self.tableView.tableHeaderView = self.searchController.searchBar;
        }
        
        self.definesPresentationContext = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.backgroundColor = FLEXSystemBackgroundColor;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"LiveObjectCell"];
    
    // 添加刷新控件
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refreshLiveObjects) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;
    
    // 添加导航栏按钮
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] 
                                             initWithTitle:@"全部加载"
                                             style:UIBarButtonItemStylePlain
                                             target:self
                                             action:@selector(loadAllClasses)];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithTitle:@"清除"
                                            style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(clearTrackedClasses)];
    
    // 初始加载
    [self loadInitialClasses];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshLiveObjects];
}

- (void)loadInitialClasses {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 获取常见的系统类
        NSArray *commonClasses = @[
            [UIView class],
            [UIViewController class],
            [UILabel class],
            [UIButton class],
            [UIImageView class],
            [UITableView class],
            [UICollectionView class],
            [UIScrollView class],
            [UITextField class],
            [UITextView class],
            [UINavigationController class],
            [UITabBarController class],
            [NSString class],
            [NSMutableString class],
            [NSArray class],
            [NSMutableArray class],
            [NSDictionary class],
            [NSMutableDictionary class],
            [NSData class],
            [NSMutableData class],
            [NSDate class],
            [NSURL class],
            [NSURLRequest class],
            [NSOperation class],
            [NSOperationQueue class]
        ];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.trackedClasses addObjectsFromArray:commonClasses];
            [self refreshLiveObjects];
        });
    });
}

- (void)loadAllClasses {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        unsigned int classCount = 0;
        Class *allClasses = objc_copyClassList(&classCount);
        
        NSMutableArray *classes = [NSMutableArray arrayWithCapacity:classCount];
        for (unsigned int i = 0; i < classCount; i++) {
            [classes addObject:allClasses[i]];
        }
        
        free(allClasses);
        
        // 按类名排序
        [classes sortUsingComparator:^NSComparisonResult(Class class1, Class class2) {
            NSString *name1 = NSStringFromClass(class1);
            NSString *name2 = NSStringFromClass(class2);
            return [name1 compare:name2];
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.trackedClasses removeAllObjects];
            [self.trackedClasses addObjectsFromArray:classes];
            [self refreshLiveObjects];
        });
    });
}

- (void)clearTrackedClasses {
    [self.trackedClasses removeAllObjects];
    [self.classCounts removeAllObjects];
    [self.tableView reloadData];
}

- (void)refreshLiveObjects {
    if (self.trackedClasses.count == 0) {
        [self.refreshControl endRefreshing];
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableDictionary *newCounts = [NSMutableDictionary dictionary];
        
        for (Class cls in self.trackedClasses) {
            NSUInteger count = [self countInstancesOfClass:cls];
            NSString *className = NSStringFromClass(cls);
            newCounts[className] = @(count);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.classCounts = newCounts;
            [self.tableView reloadData];
            [self.refreshControl endRefreshing];
        });
    });
}

- (NSUInteger)countInstancesOfClass:(Class)cls {
    __block NSUInteger count = 0;
    
    // 使用 FLEXHeapEnumerator 来计数实例
    [FLEXHeapEnumerator enumerateLiveObjectsUsingBlock:^(__unsafe_unretained id object, __unsafe_unretained Class actualClass) {
        if ([object isKindOfClass:cls]) {
            count++;
        }
    }];
    
    return count;
}

- (NSArray<id> *)instancesOfClass:(Class)cls {
    NSMutableArray *instances = [NSMutableArray array];
    
    [FLEXHeapEnumerator enumerateLiveObjectsUsingBlock:^(__unsafe_unretained id object, __unsafe_unretained Class actualClass) {
        if ([object isKindOfClass:cls]) {
            [instances addObject:object];
            // 限制数量以避免内存问题
            if (instances.count >= 1000) {
                return;
            }
        }
    }];
    
    return [instances copy];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.isSearching) {
        return self.filteredClasses.count;
    }
    return self.trackedClasses.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LiveObjectCell" forIndexPath:indexPath];
    
    Class cls;
    if (self.isSearching) {
        cls = self.filteredClasses[indexPath.row];
    } else {
        cls = self.trackedClasses[indexPath.row];
    }
    
    NSString *className = NSStringFromClass(cls);
    NSNumber *count = self.classCounts[className];
    
    cell.textLabel.text = className;
    cell.detailTextLabel.text = count ? [NSString stringWithFormat:@"%@ 个实例", count] : @"计算中...";
    
    // 根据实例数量设置颜色
    NSUInteger instanceCount = count.unsignedIntegerValue;
    if (instanceCount == 0) {
        cell.textLabel.textColor = FLEXSystemGrayColor;
    } else if (instanceCount > 100) {
        cell.textLabel.textColor = FLEXSystemRedColor;
    } else if (instanceCount > 10) {
        cell.textLabel.textColor = FLEXSystemOrangeColor;
    } else {
        cell.textLabel.textColor = FLEXLabelColor;
    }
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    Class cls;
    if (self.isSearching) {
        cls = self.filteredClasses[indexPath.row];
    } else {
        cls = self.trackedClasses[indexPath.row];
    }
    
    [self showInstancesOfClass:cls];
}

- (void)showInstancesOfClass:(Class)cls {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *instances = [self instancesOfClass:cls];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (instances.count == 0) {
                UIAlertController *alert = [UIAlertController 
                                           alertControllerWithTitle:@"没有实例" 
                                           message:[NSString stringWithFormat:@"类 %@ 当前没有活动实例", NSStringFromClass(cls)]
                                           preferredStyle:UIAlertControllerStyleAlert];
                
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
                [alert addAction:okAction];
                
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                FLEXLiveObjectsInstanceViewController *instanceController = [[FLEXLiveObjectsInstanceViewController alloc] initWithInstances:instances forClass:cls];
                [self.navigationController pushViewController:instanceController animated:YES];
            }
        });
    });
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchText = searchController.searchBar.text;
    [self filterClassesWithSearchText:searchText];
}

#pragma mark - UISearchBarDelegate

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    self.isSearching = YES;
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    if (searchBar.text.length == 0) {
        self.isSearching = NO;
        [self.tableView reloadData];
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    self.isSearching = NO;
    [self.tableView reloadData];
}

- (void)filterClassesWithSearchText:(NSString *)searchText {
    if (searchText.length == 0) {
        self.isSearching = NO;
        self.filteredClasses = @[];
    } else {
        self.isSearching = YES;
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(Class cls, NSDictionary *bindings) {
            NSString *className = NSStringFromClass(cls);
            return [className.lowercaseString containsString:searchText.lowercaseString];
        }];
        self.filteredClasses = [self.trackedClasses filteredArrayUsingPredicate:predicate];
    }
    
    [self.tableView reloadData];
}

@end

@implementation FLEXLiveObjectsInstanceViewController

- (instancetype)initWithInstances:(NSArray *)instances forClass:(Class)cls {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _instances = [instances copy];
        _targetClass = cls;
        self.title = [NSString stringWithFormat:@"%@ (%lu)", NSStringFromClass(cls), (unsigned long)instances.count];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.backgroundColor = FLEXSystemBackgroundColor;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"InstanceCell"];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.instances.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"InstanceCell" forIndexPath:indexPath];
    
    id instance = self.instances[indexPath.row];
    
    cell.textLabel.text = [FLEXRuntimeUtility safeClassNameForObject:instance];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%p", instance];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    id instance = self.instances[indexPath.row];
    FLEXObjectExplorerViewController *explorer = [FLEXObjectExplorerViewController exploringObject:instance];
    [self.navigationController pushViewController:explorer animated:YES];
}

@end
