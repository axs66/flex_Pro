//
//  RTBViewHierarchyVC.m
//  pxx917144686
//
//  Created for RuntimeBrowser
//

#import "RTBViewHierarchyVC.h"

@interface RTBViewHierarchyVC () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) NSMutableArray *expandedViews;  // 记录展开的视图

@end

@implementation RTBViewHierarchyVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"视图层级";
    
    // 添加关闭按钮
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                                                                         target:self 
                                                                                         action:@selector(close)];
    
    // 初始化表格视图
    self.tableView.rowHeight = 44.0;
    
    // 初始化数据
    self.viewsHierarchy = [NSMutableArray array];
    self.expandedViews = [NSMutableArray array];

    // 获取主窗口的根视图
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) {
                        keyWindow = w;
                        break;
                    }
                }
            }
        }
    } else {
        keyWindow = [[UIApplication sharedApplication] keyWindow];
    }
    
    if (!self.targetView && keyWindow) {
        self.targetView = keyWindow;
    }
    
    // 构建视图层级
    [self buildViewHierarchy];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)buildViewHierarchy {
    [self.viewsHierarchy removeAllObjects];
    [self addViewAndSubviewsToHierarchy:self.targetView withLevel:0];
}

- (void)addViewAndSubviewsToHierarchy:(UIView *)view withLevel:(NSInteger)level {
    NSDictionary *viewInfo = @{
        @"view": view,
        @"level": @(level),
        @"hasSubviews": @(view.subviews.count > 0)
    };
    
    [self.viewsHierarchy addObject:viewInfo];
    
    if ([self.expandedViews containsObject:view]) {
        for (UIView *subview in view.subviews) {
            [self addViewAndSubviewsToHierarchy:subview withLevel:level + 1];
        }
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.viewsHierarchy.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"ViewCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    NSDictionary *viewInfo = self.viewsHierarchy[indexPath.row];
    UIView *view = viewInfo[@"view"];
    NSInteger level = [viewInfo[@"level"] integerValue];
    BOOL hasSubviews = [viewInfo[@"hasSubviews"] boolValue];
    
    NSMutableString *prefix = [NSMutableString string];
    for (NSInteger i = 0; i < level; i++) {
        [prefix appendString:@"    "];
    }
    
    if (hasSubviews) {
        [prefix appendString:[self.expandedViews containsObject:view] ? @"▼ " : @"▶ "];
    } else {
        [prefix appendString:@"• "];
    }
    
    cell.textLabel.text = [NSString stringWithFormat:@"%@%@", prefix, NSStringFromClass([view class])];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Frame: (%.1f, %.1f, %.1f, %.1f)", 
                                view.frame.origin.x, view.frame.origin.y, 
                                view.frame.size.width, view.frame.size.height];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *viewInfo = self.viewsHierarchy[indexPath.row];
    UIView *view = viewInfo[@"view"];
    BOOL hasSubviews = [viewInfo[@"hasSubviews"] boolValue];
    
    if (hasSubviews) {
        // 展开/折叠视图
        if ([self.expandedViews containsObject:view]) {
            [self.expandedViews removeObject:view];
        } else {
            [self.expandedViews addObject:view];
        }
        
        // 重建视图层级并刷新表格
        [self buildViewHierarchy];
        [self.tableView reloadData];
    } else {
        // 显示视图详情
        [self showDetailsForView:view];
    }
}

- (void)showDetailsForView:(UIView *)view {
    UIViewController *detailVC = [[UIViewController alloc] init];
    detailVC.title = NSStringFromClass([view class]);
    
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:detailVC.view.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [detailVC.view addSubview:scrollView];
    
    // 添加视图属性信息
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(10, 10, detailVC.view.bounds.size.width - 20, 400)];
    textView.editable = NO;
    textView.text = [self getViewDetails:view];
    [scrollView addSubview:textView];
    
    scrollView.contentSize = CGSizeMake(scrollView.bounds.size.width, textView.frame.size.height + 20);
    
    [self.navigationController pushViewController:detailVC animated:YES];
}

- (NSString *)getViewDetails:(UIView *)view {
    NSMutableString *details = [NSMutableString string];
    
    [details appendFormat:@"类名: %@\n", NSStringFromClass([view class])];
    [details appendFormat:@"地址: %p\n", view];
    [details appendFormat:@"Frame: %@\n", NSStringFromCGRect(view.frame)];
    [details appendFormat:@"Bounds: %@\n", NSStringFromCGRect(view.bounds)];
    [details appendFormat:@"Center: %@\n", NSStringFromCGPoint(view.center)];
    [details appendFormat:@"Transform: %@\n", NSStringFromCGAffineTransform(view.transform)];
    [details appendFormat:@"Alpha: %.2f\n", view.alpha];
    [details appendFormat:@"Hidden: %@\n", view.hidden ? @"YES" : @"NO"];
    [details appendFormat:@"Opaque: %@\n", view.opaque ? @"YES" : @"NO"];
    [details appendFormat:@"Clips to Bounds: %@\n", view.clipsToBounds ? @"YES" : @"NO"];
    [details appendFormat:@"背景色: %@\n", [self colorDescription:view.backgroundColor]];
    [details appendFormat:@"Tag: %ld\n", (long)view.tag];
    [details appendFormat:@"User Interaction Enabled: %@\n", view.userInteractionEnabled ? @"YES" : @"NO"];
    [details appendFormat:@"Multiple Touch Enabled: %@\n", view.multipleTouchEnabled ? @"YES" : @"NO"];
    [details appendFormat:@"Exclus. Touch: %@\n", view.exclusiveTouch ? @"YES" : @"NO"];
    
    return details;
}

- (NSString *)colorDescription:(UIColor *)color {
    if (!color) return @"nil";
    
    CGFloat r, g, b, a;
    if ([color getRed:&r green:&g blue:&b alpha:&a]) {
        return [NSString stringWithFormat:@"R:%.2f G:%.2f B:%.2f A:%.2f", r, g, b, a];
    }
    return @"Unknown color format";
}

@end