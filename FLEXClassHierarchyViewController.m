#import "FLEXClassHierarchyViewController.h"
#import "FLEXRuntimeClient+RuntimeBrowser.h"
#import <objc/runtime.h>

@interface FLEXClassHierarchyViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) Class classObject;
@property (nonatomic, strong) NSArray *hierarchyClasses;
@property (nonatomic, strong) NSArray *subclasses;
@property (nonatomic, strong) UISegmentedControl *viewModeSegment;
@property (nonatomic, assign) BOOL showingSubclasses;

// 添加属性
@property (nonatomic, strong) NSArray *instances;
@property (nonatomic, assign) BOOL showingInstances;
@property (nonatomic, strong) UIRefreshControl *refreshControl;

@end

@implementation FLEXClassHierarchyViewController

- (instancetype)initWithClass:(Class)aClass {
    self = [super init];
    if (self) {
        self.classObject = aClass;
        self.showingSubclasses = NO;
    }
    return self;
}

- (instancetype)initWithClassName:(NSString *)className {
    Class classObj = NSClassFromString(className);
    return [self initWithClass:classObj];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = NSStringFromClass(self.classObject);
    
    // 设置导航栏
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] 
        initWithBarButtonSystemItem:UIBarButtonSystemItemAction 
        target:self 
        action:@selector(shareClassInfo)];
    
    // 设置分段控制
    self.viewModeSegment = [[UISegmentedControl alloc] initWithItems:@[@"父类层次", @"子类", @"实例"]];
    self.viewModeSegment.selectedSegmentIndex = 0;
    [self.viewModeSegment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = self.viewModeSegment;
    
    // 设置表格视图
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    
    // 添加刷新控制
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshData) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;
    
    // 加载数据
    [self loadHierarchyData];
}

- (void)loadHierarchyData {
    // 加载父类层次
    NSMutableArray *hierarchy = [NSMutableArray array];
    Class currentClass = self.classObject;
    
    while (currentClass) {
        [hierarchy addObject:currentClass];
        currentClass = class_getSuperclass(currentClass);
    }
    self.hierarchyClasses = hierarchy;
    
    // 加载子类
    NSMutableArray *subclasses = [NSMutableArray array];
    NSArray *allSubclasses = [[FLEXRuntimeClient runtime] subclassesOfClass:NSStringFromClass(self.classObject)];
    
    for (NSString *className in allSubclasses) {
        Class cls = NSClassFromString(className);
        if (cls) {
            [subclasses addObject:cls];
        }
    }
    
    self.subclasses = subclasses;
    
    [self.tableView reloadData];
}

- (void)refreshData {
    [self loadHierarchyData];
    [self.refreshControl endRefreshing];
}

- (void)shareClassInfo {
    // 移除未使用的变量
    // NSDictionary *classInfo = [[FLEXRuntimeClient runtime] getDetailedClassInfo:self.classObject];
    NSString *header = [[FLEXRuntimeClient runtime] generateHeaderForClass:self.classObject];
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] 
        initWithActivityItems:@[header] 
        applicationActivities:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }
    
    [self presentViewController:activityVC animated:YES completion:nil];
}

// 在segmentChanged方法中添加实例查看功能
- (void)segmentChanged:(UISegmentedControl *)sender {
    self.showingSubclasses = (sender.selectedSegmentIndex == 1);
    self.showingInstances = (sender.selectedSegmentIndex == 2);
    
    if (self.showingInstances) {
        [self loadInstancesData];
    }
    
    [self.tableView reloadData];
}

- (void)loadInstancesData {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *instances = [[FLEXRuntimeClient runtime] getAllInstancesOfClass:self.classObject];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.instances = instances;
            [self.tableView reloadData];
        });
    });
}

#pragma mark - UITableViewDelegate & UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.showingInstances) {
        return self.instances.count;
    } else if (self.showingSubclasses) {
        return self.subclasses.count;
    } else {
        return self.hierarchyClasses.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"ClassCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    if (self.showingInstances) {
        id instance = self.instances[indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"<%@: %p>", NSStringFromClass([instance class]), instance];
        cell.detailTextLabel.text = [instance description];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        // 现有的类和子类显示逻辑
        Class cls = nil;
        if (self.showingSubclasses) {
            cls = self.subclasses[indexPath.row];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"方法: %lu | 属性: %lu", 
                (unsigned long)[self methodCountForClass:cls], (unsigned long)[self propertyCountForClass:cls]];
        } else {
            cls = self.hierarchyClasses[indexPath.row];
            if (indexPath.row == 0) {
                cell.detailTextLabel.text = @"当前类";
            } else {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"父类 (Level %ld)", (long)indexPath.row];
            }
        }
        
        cell.textLabel.text = NSStringFromClass(cls);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        // 高亮当前类
        if (!self.showingSubclasses && !self.showingInstances && indexPath.row == 0) {
            cell.textLabel.textColor = [UIColor systemBlueColor];
            cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
        } else {
            if (@available(iOS 13.0, *)) {
                cell.textLabel.textColor = [UIColor labelColor];
            } else {
                cell.textLabel.textColor = [UIColor blackColor];
            }
            cell.textLabel.font = [UIFont systemFontOfSize:17];
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (self.showingInstances) {
        id instance = self.instances[indexPath.row];
        UIViewController *detailVC = [[NSClassFromString(@"FLEXObjectExplorerViewController") alloc] initWithObject:instance];
        if (detailVC) {
            [self.navigationController pushViewController:detailVC animated:YES];
        }
    } else {
        Class selectedClass = nil;
        
        if (self.showingSubclasses) {
            selectedClass = self.subclasses[indexPath.row];
        } else {
            selectedClass = self.hierarchyClasses[indexPath.row];
        }
        
        // 跳转到类详情视图
        UIViewController *detailVC = [[NSClassFromString(@"FLEXObjectExplorerViewController") alloc] initWithObject:selectedClass];
        if (!detailVC) {
            detailVC = [[FLEXClassHierarchyViewController alloc] initWithClass:selectedClass];
        }
        [self.navigationController pushViewController:detailVC animated:YES];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.showingInstances) {
        return [NSString stringWithFormat:@"%@ 的实例 (%lu)", NSStringFromClass(self.classObject), (unsigned long)self.instances.count];
    } else if (self.showingSubclasses) {
        return [NSString stringWithFormat:@"%@ 的子类 (%lu)", NSStringFromClass(self.classObject), (unsigned long)self.subclasses.count];
    } else {
        return [NSString stringWithFormat:@"%@ 的继承层次", NSStringFromClass(self.classObject)];
    }
}

#pragma mark - 辅助方法

- (NSUInteger)methodCountForClass:(Class)cls {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    if (methods) free(methods);
    
    unsigned int classMethods = 0;
    Method *classMthds = class_copyMethodList(object_getClass(cls), &classMethods);
    if (classMthds) free(classMthds);
    
    return methodCount + classMethods;
}

- (NSUInteger)propertyCountForClass:(Class)cls {
    unsigned int count = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &count);
    if (properties) free(properties);
    return count;
}

@end