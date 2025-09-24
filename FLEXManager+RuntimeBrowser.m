#import "FLEXManager+RuntimeBrowser.h"
#import "FLEXManager+Extensibility.h"
#import "FLEXToolbarItem.h"
#import "FLEXUtility.h"
#import "FLEXExplorerViewController.h"
#import "FLEXRuntimeClient+RuntimeBrowser.h"
#import "FLEXRuntimeBrowserViewController.h"
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach/task.h>

@class FLEXExplorerViewController; // 使用前向声明替代重复的接口定义

@interface FLEXManager ()
@property (nonatomic, strong, readwrite) FLEXExplorerViewController *explorerViewController;
@end

@implementation FLEXManager (RuntimeBrowser)

- (void)registerRuntimeBrowserTools {
    // 注册运行时浏览器工具栏项
    UIImage *runtimeImage;
    if (@available(iOS 13.0, *)) {
        runtimeImage = [UIImage systemImageNamed:@"cpu"];
    } else {
        runtimeImage = [UIImage imageNamed:@"flex_runtime"] ?: [UIImage new];
    }
    FLEXToolbarItem *runtimeBrowserItem = [FLEXToolbarItem 
        toolbarItemWithTitle:@"运行时浏览器"
        image:runtimeImage
    ];
    
    runtimeBrowserItem.action = ^{
        [self showRuntimeBrowser];
    };
    
    // 全局工具栏
    [self registerGlobalEntryWithName:@"运行时浏览器" viewControllerFutureBlock:^UIViewController * {
        return [FLEXRuntimeBrowserViewController new];
    }];
    
    // 注册类浏览器工具
    UIImage *classImage;
    if (@available(iOS 13.0, *)) {
        classImage = [UIImage systemImageNamed:@"list.bullet.rectangle"];
    } else {
        classImage = [UIImage imageNamed:@"flex_classes"] ?: [UIImage new];
    }
    FLEXToolbarItem *classBrowserItem = [FLEXToolbarItem 
        toolbarItemWithTitle:@"类浏览器"
        image:classImage
    ];
    
    classBrowserItem.action = ^{
        [self showClassBrowser];
    };
    
    [self registerGlobalEntryWithName:@"类浏览器" 
         viewControllerFutureBlock:^UIViewController *{
             return [FLEXRuntimeBrowserViewController new];
         }];
    
    // 注册实例查找器工具
    UIImage *finderImage;
    if (@available(iOS 13.0, *)) {
        finderImage = [UIImage systemImageNamed:@"magnifyingglass.circle"];
    } else {
        finderImage = [UIImage imageNamed:@"flex_finder"] ?: [UIImage new];
    }
    FLEXToolbarItem *instanceFinderItem = [FLEXToolbarItem 
        toolbarItemWithTitle:@"实例查找器"
        image:finderImage
    ];
    
    instanceFinderItem.action = ^{
        [self showInstanceFinder];
    };
    
    [self registerGlobalEntryWithName:@"实例查找器" 
         viewControllerFutureBlock:^UIViewController *{
             // 先创建视图控制器
             UIViewController *vc = [[UIViewController alloc] init]; // 使用适当的视图控制器类
             
             // 然后异步调用showInstanceFinder
             dispatch_async(dispatch_get_main_queue(), ^{
                 [self showInstanceFinder];
             });
             
             return vc;
         }];
}

- (void)showRuntimeBrowser {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"运行时浏览器"
                                                                   message:@"选择浏览模式"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    // 浏览所有类
    UIAlertAction *allClassesAction = [UIAlertAction actionWithTitle:@"所有类"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
        [self showAllClasses];
    }];
    
    // 浏览系统框架
    UIAlertAction *frameworksAction = [UIAlertAction actionWithTitle:@"系统框架"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
        [self showSystemFrameworks];
    }];
    
    // 浏览应用类
    UIAlertAction *appClassesAction = [UIAlertAction actionWithTitle:@"应用类"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
        [self showApplicationClasses];
    }];
    
    // 内存分析
    UIAlertAction *memoryAnalysisAction = [UIAlertAction actionWithTitle:@"内存分析"
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction *action) {
        [self showMemoryAnalysis];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    [alert addAction:allClassesAction];
    [alert addAction:frameworksAction];
    [alert addAction:appClassesAction];
    [alert addAction:memoryAnalysisAction];
    [alert addAction:cancelAction];
    
    UIViewController *presenter = [FLEXManager sharedManager].explorerViewController;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = presenter.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(presenter.view.bounds.size.width/2, 
                                                                   presenter.view.bounds.size.height/2, 
                                                                   1, 1);
    }
    
    [presenter presentViewController:alert animated:YES completion:nil];
}

- (void)showAllClasses {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        unsigned int classCount = 0;
        Class *classes = objc_copyClassList(&classCount);
        
        NSMutableArray *classNames = [NSMutableArray arrayWithCapacity:classCount];
        
        for (unsigned int i = 0; i < classCount; i++) {
            Class cls = classes[i];
            NSString *className = NSStringFromClass(cls);
            if (className) {
                [classNames addObject:@{
                    @"name": className,
                    @"class": cls,
                    @"type": @"class"
                }];
            }
        }
        
        free(classes);
        
        // 按名称排序
        [classNames sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            return [obj1[@"name"] compare:obj2[@"name"]];
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentClassListViewController:classNames title:@"所有类"];
        });
    });
}

- (void)showSystemFrameworks {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        unsigned int classCount = 0;
        Class *classes = objc_copyClassList(&classCount);
        
        NSMutableDictionary *frameworkClasses = [NSMutableDictionary dictionary];
        
        for (unsigned int i = 0; i < classCount; i++) {
            Class cls = classes[i];
            NSString *className = NSStringFromClass(cls);
            
            if (className) {
                NSString *frameworkName = [self getFrameworkNameForClass:cls];
                if (frameworkName) {
                    NSMutableArray *classes = frameworkClasses[frameworkName];
                    if (!classes) {
                        classes = [NSMutableArray array];
                        frameworkClasses[frameworkName] = classes;
                    }
                    [classes addObject:@{
                        @"name": className,
                        @"class": cls,
                        @"type": @"class"
                    }];
                }
            }
        }
        
        free(classes);
        
        // 整理框架列表
        NSMutableArray *frameworkList = [NSMutableArray array];
        for (NSString *frameworkName in [frameworkClasses.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            NSArray *classes = frameworkClasses[frameworkName];
            [frameworkList addObject:@{
                @"name": frameworkName,
                @"classes": classes,
                @"type": @"framework"
            }];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentFrameworkListViewController:frameworkList];
        });
    });
}

- (void)showApplicationClasses {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        unsigned int classCount = 0;
        Class *classes = objc_copyClassList(&classCount);
        
        NSMutableArray *appClasses = [NSMutableArray array];
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        
        for (unsigned int i = 0; i < classCount; i++) {
            Class cls = classes[i];
            NSString *className = NSStringFromClass(cls);
            
            if (className) {
                // 判断是否为应用类（简单判断：不包含系统前缀）
                if (![self isSystemClass:cls] && [self isAppClass:cls bundleId:bundleIdentifier]) {
                    [appClasses addObject:@{
                        @"name": className,
                        @"class": cls,
                        @"type": @"class"
                    }];
                }
            }
        }
        
        free(classes);
        
        // 按名称排序
        [appClasses sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            return [obj1[@"name"] compare:obj2[@"name"]];
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentClassListViewController:appClasses title:@"应用类"];
        });
    });
}

- (void)showMemoryAnalysis {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *memoryInfo = [NSMutableArray array];
        
        // 获取内存使用情况
        struct mach_task_basic_info info;
        mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
        kern_return_t kerr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &size);
        
        if (kerr == KERN_SUCCESS) {
            [memoryInfo addObject:@{
                @"name": @"常驻内存",
                @"value": [self formatBytes:info.resident_size],
                @"type": @"memory"
            }];
            
            [memoryInfo addObject:@{
                @"name": @"虚拟内存",
                @"value": [self formatBytes:info.virtual_size],
                @"type": @"memory"
            }];
        }
        
        // 类实例数量统计
        [self addClassInstanceCounts:memoryInfo];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentMemoryAnalysisViewController:memoryInfo];
        });
    });
}

- (NSString *)getFrameworkNameForClass:(Class)cls {
    // 获取类所在的动态库路径
    const char *imageName = class_getImageName(cls);
    if (imageName) {
        NSString *imageNameString = @(imageName);
        NSString *frameworkName = [imageNameString lastPathComponent];
        
        // 移除扩展名
        if ([frameworkName hasSuffix:@".framework"]) {
            frameworkName = [frameworkName stringByDeletingPathExtension];
        } else if ([frameworkName hasSuffix:@".dylib"]) {
            frameworkName = [frameworkName stringByDeletingPathExtension];
        }
        
        return frameworkName;
    }
    
    return nil;
}

- (BOOL)isSystemClass:(Class)cls {
    NSString *className = NSStringFromClass(cls);
    
    // 系统类通常以这些前缀开头
    NSArray *systemPrefixes = @[@"NS", @"UI", @"CA", @"CG", @"CF", @"__", @"_"];
    
    for (NSString *prefix in systemPrefixes) {
        if ([className hasPrefix:prefix]) {
            return YES;
        }
    }
    
    // 检查是否在系统框架中
    const char *imageName = class_getImageName(cls);
    if (imageName) {
        NSString *imageNameString = @(imageName);
        if ([imageNameString containsString:@"/System/Library/"] || 
            [imageNameString containsString:@"/usr/lib/"]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isAppClass:(Class)cls bundleId:(NSString *)bundleId {
    const char *imageName = class_getImageName(cls);
    if (imageName) {
        NSString *imageNameString = @(imageName);
        return [imageNameString containsString:bundleId];
    }
    
    return NO;
}

- (void)addClassInstanceCounts:(NSMutableArray *)memoryInfo {
    // 统计常见类的实例数量
    NSArray *commonClasses = @[
        [UIView class],
        [UIViewController class],
        [UILabel class],
        [UIButton class],
        [UIImageView class],
        [NSString class],
        [NSArray class],
        [NSDictionary class]
    ];
    
    FLEXRuntimeClient *client = [FLEXRuntimeClient new];
    
    for (Class cls in commonClasses) {
        NSUInteger count = [client getInstanceCountForClass:cls];
        [memoryInfo addObject:@{
            @"name": [NSString stringWithFormat:@"%@ 实例", NSStringFromClass(cls)],
            @"value": @(count).stringValue,
            @"type": @"instance"
        }];
    }
}

- (NSString *)formatBytes:(vm_size_t)bytes {
    if (bytes < 1024) {
        return [NSString stringWithFormat:@"%lu B", (unsigned long)bytes];
    } else if (bytes < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f KB", (double)bytes / 1024];
    } else if (bytes < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f MB", (double)bytes / (1024 * 1024)];
    } else {
        return [NSString stringWithFormat:@"%.2f GB", (double)bytes / (1024 * 1024 * 1024)];
    }
}

- (void)presentClassListViewController:(NSArray *)classes title:(NSString *)title {
    UITableViewController *classListController = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    classListController.title = title;
    
    // 设置数据源和代理
    [self setupClassListViewController:classListController withClasses:classes];
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:classListController];
    
    UIViewController *presenter = [FLEXManager sharedManager].explorerViewController;
    [presenter presentViewController:nav animated:YES completion:nil];
}

- (void)setupClassListViewController:(UITableViewController *)controller withClasses:(NSArray *)classes {
    // 存储类数据
    objc_setAssociatedObject(controller, "classes", classes, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 设置表格视图
    [controller.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ClassCell"];
    
    // 重写数据源方法
    controller.tableView.dataSource = (id<UITableViewDataSource>)self;
    controller.tableView.delegate = (id<UITableViewDelegate>)self;
    
    // 添加关闭按钮
    controller.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                                  initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                  target:self
                                                  action:@selector(dismissClassList:)];
}

- (void)dismissClassList:(UIBarButtonItem *)sender {
    UIViewController *presenter = [FLEXManager sharedManager].explorerViewController;
    [presenter dismissViewControllerAnimated:YES completion:nil];
}

- (void)presentFrameworkListViewController:(NSArray *)frameworks {
    // 实现框架列表展示
    UITableViewController *frameworkController = [[UITableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    frameworkController.title = @"系统框架";
    
    // 类似的实现...
    objc_setAssociatedObject(frameworkController, "frameworks", frameworks, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:frameworkController];
    
    UIViewController *presenter = [FLEXManager sharedManager].explorerViewController;
    [presenter presentViewController:nav animated:YES completion:nil];
}

- (void)presentMemoryAnalysisViewController:(NSArray *)memoryInfo {
    // 实现内存分析展示
    UITableViewController *memoryController = [[UITableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    memoryController.title = @"内存分析";
    
    objc_setAssociatedObject(memoryController, "memoryInfo", memoryInfo, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:memoryController];
    
    UIViewController *presenter = [FLEXManager sharedManager].explorerViewController;
    [presenter presentViewController:nav animated:YES completion:nil];
}

- (void)showClassBrowser {
    [self showAllClasses];
}

- (void)showInstanceFinder {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"实例查找器"
                                                                   message:@"输入类名查找实例"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"类名 (如: UIViewController)";
    }];
    
    UIAlertAction *searchAction = [UIAlertAction actionWithTitle:@"查找"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
        NSString *className = alert.textFields[0].text;
        [self findInstancesOfClass:className];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    [alert addAction:searchAction];
    [alert addAction:cancelAction];
    
    UIViewController *presenter = [FLEXManager sharedManager].explorerViewController;
    [presenter presentViewController:alert animated:YES completion:nil];
}

- (void)findInstancesOfClass:(NSString *)className {
    if (!className || className.length == 0) return;
    
    Class cls = NSClassFromString(className);
    if (!cls) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"未找到类"
                                                                       message:[NSString stringWithFormat:@"类 '%@' 不存在", className]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:okAction];
        
        UIViewController *presenter = [FLEXManager sharedManager].explorerViewController;
        [presenter presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        FLEXRuntimeClient *client = [FLEXRuntimeClient new];
        NSArray *instances = [client getAllInstancesOfClass:cls];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (instances.count == 0) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"未找到实例"
                                                                               message:[NSString stringWithFormat:@"类 '%@' 没有找到任何实例", className]
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
                [alert addAction:okAction];
                
                UIViewController *presenter = [FLEXManager sharedManager].explorerViewController;
                [presenter presentViewController:alert animated:YES completion:nil];
            } else {
                [self presentInstanceListViewController:instances forClass:cls];
            }
        });
    });
}

- (void)presentInstanceListViewController:(NSArray *)instances forClass:(Class)cls {
    UITableViewController *instanceController = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    instanceController.title = [NSString stringWithFormat:@"%@ 实例 (%lu)", NSStringFromClass(cls), (unsigned long)instances.count];
    
    objc_setAssociatedObject(instanceController, "instances", instances, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(instanceController, "targetClass", cls, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [instanceController.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"InstanceCell"];
    
    instanceController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                                          initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                          target:self
                                                          action:@selector(dismissInstanceList:)];
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:instanceController];
    
    UIViewController *presenter = [FLEXManager sharedManager].explorerViewController;
    [presenter presentViewController:nav animated:YES completion:nil];
}

- (void)dismissInstanceList:(UIBarButtonItem *)sender {
    UIViewController *presenter = [FLEXManager sharedManager].explorerViewController;
    [presenter dismissViewControllerAnimated:YES completion:nil];
}

@end