//
//  FLEXKeyPathSearchController.m
//  FLEX
//
//  Created by Tanner on 3/23/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import "FLEXKeyPathSearchController.h"
#import "FLEXRuntimeKeyPathTokenizer.h"
#import "FLEXRuntimeController.h"
#import "NSString+FLEX.h"
#import "NSArray+FLEX.h"
#import "UITextField+Range.h"
#import "NSTimer+FLEX.h"
#import "FLEXTableView.h"
#import "FLEXUtility.h"
#import "FLEXObjectExplorerFactory.h"

@interface FLEXKeyPathSearchController ()

@property (nonatomic) NSTimer *timer;
/// 如果 \c keyPath 是 \c nil 或者只有 \c bundleKey，这是
/// 一个包含像 \c UICatalog 或 \c UIKit\.framework 这样的包键路径组件列表
@property (nonatomic) NSArray<NSString *> *bundlePaths;
/// 如果 \c keyPath 的首组件是有效的包的话，这个是被选择的包/框架中的类
@property (nonatomic) NSArray<NSString *> *classNames;
/// 如果 \c keyPath 中的首组件是一个有效的包，第二个组件是一个有效的类，
/// 这个是被选择的类中的方法
@property (nonatomic) NSArray<FLEXMethod *> *methods;
/// 必须是一个类的 \c FLEXMethod 数组，其中每个类都包含与筛选器匹配的方法。
/// 只有当 \c classForMethods 不为 nil 时才会被设置。
@property (nonatomic) NSArray<NSArray<FLEXMethod *> *> *methodsInClasses;
/// 显示在屏幕上的结果
@property (nonatomic) NSArray *sectionData;
@property (nonatomic) NSString *pendingKeyPath;

/// 父类链，可能是空数组
@property (nonatomic) NSArray<NSString *> *superclassNames;

/// 与当前关键字路径关联的目标类，如果没有选择类，则为 nil
@property (nonatomic) Class classForMethods;
/// 在当前 \c keyPath 的第二个组件对应类的情况下，这表示如果我们应该显示
/// 目标类的实例方法或类方法。如果 \c classForMethods 为 nil，
/// 该属性无意义。
@property (nonatomic) BOOL targetIsInstancePath;

/// 当筛选搜索结果时，只有包含 \c filterText 的项将可见。
/// 如果目标类是绝对类，我们会使用这个
@property (nonatomic) NSArray<NSString *> *filteredClassNames;
/// 无论目标类是否是绝对类，我们都会使用这个，就像上面一样
@property (nonatomic) NSArray<NSArray<FLEXMethod *> *> *classesToMethods;
@end

@implementation FLEXKeyPathSearchController

// 修改类方法，避免直接访问实例变量
+ (instancetype)delegate:(id<FLEXKeyPathSearchControllerDelegate>)delegate {
    // 使用正确的初始化方法
    return [[self alloc] initWithDelegate:delegate];
}

// 添加初始化方法
- (instancetype)initWithDelegate:(id<FLEXKeyPathSearchControllerDelegate>)delegate {
    self = [super init];
    if (self) {
        // 使用正确方式设置delegate
        self.delegate = delegate;
    }
    return self;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating) {
        [self.delegate.searchController.searchBar resignFirstResponder];
    }
}

- (void)setToolbar:(FLEXRuntimeBrowserToolbar *)toolbar {
    _toolbar = toolbar;
    self.delegate.searchController.searchBar.inputAccessoryView = toolbar;
}

- (NSArray<NSString *> *)classesOf:(NSString *)className {
    Class baseClass = NSClassFromString(className);
    if (!baseClass) {
        return @[];
    }

    // 查找类
    NSMutableArray<NSString*> *classes = [NSMutableArray arrayWithObject:className];
    while ([baseClass superclass]) {
        [classes addObject:NSStringFromClass([baseClass superclass])];
        baseClass = [baseClass superclass];
    }

    return classes;
}

#pragma mark 键路径相关

- (void)didSelectKeyPathOption:(NSString *)text {
    [_timer invalidate]; // 在选择方法时可能仍在等待刷新

    // 将 "Bundle.fooba" 更改为 "Bundle.foobar."
    NSString *orig = self.delegate.searchController.searchBar.text;
    NSString *keyPath = [orig flex_stringByReplacingLastKeyPathComponent:text];
    self.delegate.searchController.searchBar.text = keyPath;

    self.keyPath = [FLEXRuntimeKeyPathTokenizer tokenizeString:keyPath];

    // 如果选择了类，则获取类
    if (self.keyPath.classKey.isAbsolute && self.keyPath.methodKey.isAny) {
        [self didSelectAbsoluteClass:text];
    } else {
        self.classes = nil;
        self.filteredClasses = nil;
    }

    [self updateTable];
}

- (void)didSelectAbsoluteClass:(NSString *)name {
    self.classes          = [self classesOf:name];
    self.filteredClasses  = self.classes;
    self.bundlesOrClasses = nil;
    self.classesToMethods = nil;
}

- (void)didPressButton:(NSString *)text insertInto:(UISearchBar *)searchBar {
    [self.toolbar setKeyPath:self.keyPath suggestions:nil];
    
    // 自 iOS 9 起可用，在 iOS 13 中仍然存在
    UITextField *field = [searchBar valueForKey:@"_searchBarTextField"];

    if ([self searchBar:searchBar shouldChangeTextInRange:field.flex_selectedRange replacementText:text]) {
        [field replaceRange:field.selectedTextRange withText:text];
    }
}

- (NSArray<NSString *> *)suggestions {
    if (self.bundlesOrClasses) {
        if (self.classes) {
            if (self.classesToMethods) {
                // 我们已选择一个类并正在搜索元数据
                return nil;
            }
            
            // 我们当前正在搜索类
            return [self.filteredClasses flex_subArrayUpto:10];
        }
        
        if (!self.keyPath) {
            // 搜索栏为空
            return @[self.emptySuggestion];
        }
        
        // 我们当前正在搜索包
        return [self.bundlesOrClasses flex_subArrayUpto:10];
    }
    
    // 我们完全没有可搜索的内容
    return nil;
}

#pragma mark - 过滤 + UISearchBarDelegate

- (void)updateTable {
    // 在后台线程上计算方法、类或包列表
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if (self.classes) {
            // 在这里，我们的类键是"绝对的"；.classes 是超类列表
            // 我们想要显示这些类的特定方法
            // TODO: 以某种方式添加缓存
            NSMutableArray *methods = [FLEXRuntimeController
                methodsForToken:self.keyPath.methodKey
                instance:self.keyPath.instanceMethods
                inClasses:self.classes
            ].mutableCopy;
            
            // 如果我们正在搜索一个方法，则删除没有结果的类
            //
            // 注意：即使查询没有指定方法，如 `*.*.`，
            // 这也会删除没有任何方法或重写的类
            if (self.keyPath.methodKey) {
                [self setNonEmptyMethodLists:methods withClasses:self.classes.mutableCopy];
            } else {
                self.filteredClasses = self.classes;
            }
        }
        else {
            FLEXRuntimeKeyPath *keyPath = self.keyPath;
            NSArray *models = [FLEXRuntimeController dataForKeyPath:keyPath];
            if (keyPath.methodKey) { // 我们正在查看方法
                self.bundlesOrClasses = nil;
                
                NSMutableArray *methods = models.mutableCopy;
                NSMutableArray<NSString *> *classes = [
                    FLEXRuntimeController classesForKeyPath:keyPath
                ];
                self.classes = classes;
                [self setNonEmptyMethodLists:methods withClasses:classes];
            } else { // 我们正在查看包或类
                self.bundlesOrClasses = models;
                self.classesToMethods = nil;
            }
        }
        
        // 最后，在主线程上重新加载表格
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateToolbarButtons];
            [self.delegate.tableView reloadData];
        });
    });
}

- (void)updateToolbarButtons {
    // 更新工具栏按钮
    [self.toolbar setKeyPath:self.keyPath suggestions:self.suggestions];
}

/// 在移除空部分后分配 .filteredClasses 和 .classesToMethods
- (void)setNonEmptyMethodLists:(NSMutableArray<NSArray<FLEXMethod *> *> *)methods
                   withClasses:(NSMutableArray<NSString *> *)classes {
    // 删除没有方法的部分
    NSIndexSet *allEmpty = [methods indexesOfObjectsPassingTest:^BOOL(NSArray *list, NSUInteger idx, BOOL *stop) {
        return list.count == 0;
    }];
    [methods removeObjectsAtIndexes:allEmpty];
    [classes removeObjectsAtIndexes:allEmpty];
    
    self.filteredClasses = classes;
    self.classesToMethods = methods;
}

- (BOOL)searchBar:(UISearchBar *)searchBar shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    // 检查字符是否合法
    if (![FLEXRuntimeKeyPathTokenizer allowedInKeyPath:text]) {
        return NO;
    }
    
    BOOL terminatedToken = NO;
    BOOL isAppending = range.length == 0 && range.location == searchBar.text.length;
    if (isAppending && [text isEqualToString:@"."]) {
        terminatedToken = YES;
    }

    // 实际解析输入
    @try {
        text = [searchBar.text stringByReplacingCharactersInRange:range withString:text] ?: text;
        self.keyPath = [FLEXRuntimeKeyPathTokenizer tokenizeString:text];
        if (self.keyPath.classKey.isAbsolute && terminatedToken) {
            [self didSelectAbsoluteClass:self.keyPath.classKey.string];
        }
    } @catch (id e) {
        return NO;
    }

    return YES;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [_timer invalidate];

    // 安排更新计时器
    if (searchText.length) {
        if (!self.keyPath.methodKey) {
            self.classes = nil;
            self.filteredClasses = nil;
        }

        self.timer = [NSTimer flex_fireSecondsFromNow:0.15 block:^{
            [self updateTable];
        }];
    }
    // ... 或者移除所有行
    else {
        _bundlesOrClasses = [FLEXRuntimeController allBundleNames];
        _classesToMethods = nil;
        _classes = nil;
        _keyPath = nil;
        [self updateToolbarButtons];
        [self.delegate.tableView reloadData];
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    self.keyPath = FLEXRuntimeKeyPath.empty;
    [self updateTable];
}

/// 当返回并再次激活搜索栏时恢复键路径
- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    searchBar.text = self.keyPath.description;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [_timer invalidate];
    [searchBar resignFirstResponder];
    [self updateTable];
}

#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredClasses.count ?: self.bundlesOrClasses.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView
        dequeueReusableCellWithIdentifier:kFLEXMultilineDetailCell
        forIndexPath:indexPath
    ];
    
    if (self.bundlesOrClasses.count) {
        cell.accessoryType        = UITableViewCellAccessoryDetailButton;
        cell.textLabel.text       = self.bundlesOrClasses[indexPath.row];
        cell.detailTextLabel.text = nil;
        if (self.keyPath.classKey) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }
    // 每个部分一行
    else if (self.filteredClasses.count) {
        NSArray<FLEXMethod *> *methods = self.classesToMethods[indexPath.row];
        NSMutableString *summary = [NSMutableString new];
        [methods enumerateObjectsUsingBlock:^(FLEXMethod *method, NSUInteger idx, BOOL *stop) {
            NSString *format = nil;
            if (idx == methods.count-1) {
                format = @"%@%@";
                *stop = YES;
            } else if (idx < 3) {
                format = @"%@%@\n";
            } else {
                format = @"%@%@\n…";
                *stop = YES;
            }

            [summary appendFormat:format, method.isInstanceMethod ? @"-" : @"+", method.selectorString];
        }];

        cell.accessoryType        = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.text       = self.filteredClasses[indexPath.row];
        if (@available(iOS 10, *)) {
            cell.detailTextLabel.text = summary.length ? summary : nil;
        }

    }
    else {
        @throw NSInternalInconsistencyException;
    }

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.filteredClasses || self.keyPath.methodKey) {
        return @" ";
    } else if (self.bundlesOrClasses) {
        NSInteger count = self.bundlesOrClasses.count;
        if (self.keyPath.classKey) {
            return FLEXPluralString(count, @"类", @"类");
        } else {
            return FLEXPluralString(count, @"包", @"包");
        }
    }

    return [self.delegate tableView:tableView titleForHeaderInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (self.filteredClasses || self.keyPath.methodKey) {
        if (section == 0) {
            return 55;
        }

        return 0;
    }

    return 55;
}

#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.bundlesOrClasses) {
        NSString *bundleSuffixOrClass = self.bundlesOrClasses[indexPath.row];
        if (self.keyPath.classKey) {
            NSParameterAssert(NSClassFromString(bundleSuffixOrClass));
            [self.delegate didSelectClass:NSClassFromString(bundleSuffixOrClass)];
        } else {
            // 选择了一个包
            [self didSelectKeyPathOption:bundleSuffixOrClass];
        }
    } else {
        if (self.filteredClasses.count) {
            Class cls = NSClassFromString(self.filteredClasses[indexPath.row]);
            NSParameterAssert(cls);
            [self.delegate didSelectClass:cls];
        } else {
            @throw NSInternalInconsistencyException;
        }
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    NSString *bundleSuffixOrClass = self.bundlesOrClasses[indexPath.row];
    NSString *imagePath = [FLEXRuntimeController imagePathWithShortName:bundleSuffixOrClass];
    NSBundle *bundle = [NSBundle bundleWithPath:imagePath.stringByDeletingLastPathComponent];

    if (bundle) {
        [self.delegate didSelectBundle:bundle];
    } else {
        [self.delegate didSelectImagePath:imagePath shortName:bundleSuffixOrClass];
    }
}

@end

