#import "RTBViewInspector.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

@interface RTBViewInspector ()
@property (nonatomic, strong) UIView *visualBorder;
@property (nonatomic, strong) UIWindow *infoWindow;
@property (nonatomic, strong) NSMutableArray *viewHierarchy;
@end

@implementation RTBViewInspector

#pragma mark - 单例方法

+ (instancetype)sharedInspector {
    static RTBViewInspector *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RTBViewInspector alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _visualBorder = [[UIView alloc] init];
        _visualBorder.layer.borderWidth = 2.0;
        _visualBorder.layer.borderColor = [UIColor redColor].CGColor;
        _visualBorder.userInteractionEnabled = NO;
        
        _infoWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 80, [UIScreen mainScreen].bounds.size.width, 120)];
        _infoWindow.windowLevel = UIWindowLevelAlert + 100;
        _infoWindow.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
        _infoWindow.hidden = YES;
        
        _viewHierarchy = [NSMutableArray array];
    }
    return self;
}

#pragma mark - 视图层次结构检查

- (void)inspectViewHierarchy:(UIView *)rootView {
    if (!rootView) return;
    
    [self.viewHierarchy removeAllObjects];
    [self addViewAndSubviewsToHierarchy:rootView withLevel:0];
    
    // 显示层次结构信息窗口
    [self showInfoWindow];
}

- (void)addViewAndSubviewsToHierarchy:(UIView *)view withLevel:(NSInteger)level {
    NSDictionary *viewInfo = @{
        @"view": view,
        @"level": @(level),
        @"class": NSStringFromClass([view class]),
        @"frame": NSStringFromCGRect(view.frame)
    };
    
    [self.viewHierarchy addObject:viewInfo];
    
    for (UIView *subview in view.subviews) {
        [self addViewAndSubviewsToHierarchy:subview withLevel:level + 1];
    }
}

- (void)showInfoWindow {
    UIViewController *rootVC = [[UIViewController alloc] init];
    self.infoWindow.rootViewController = rootVC;
    
    UILabel *infoLabel = [[UILabel alloc] initWithFrame:self.infoWindow.bounds];
    infoLabel.textColor = [UIColor whiteColor];
    infoLabel.font = [UIFont systemFontOfSize:12];
    infoLabel.numberOfLines = 0;
    infoLabel.text = [NSString stringWithFormat:@"已检测到 %lu 个视图", (unsigned long)self.viewHierarchy.count];
    
    [rootVC.view addSubview:infoLabel];
    
    // 添加手势
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissInfoWindow)];
    [rootVC.view addGestureRecognizer:tapGesture];
    
    self.infoWindow.hidden = NO;
}

- (void)dismissInfoWindow {
    // 原来的代码有错误：
    // for (UIGestureRecognizer *gesture in self.infoWindow.rootViewController.view.gestureRecognizers) {
    //     if ([NSStringFromSelector(gesture.action) isEqualToString:NSStringFromSelector(@selector(dismissInfoWindow))]) {
    //         [self.infoWindow.rootViewController.view removeGestureRecognizer:gesture];
    //     }
    // }
    
    // 修复后的代码 - 简单地移除所有手势识别器
    for (UIGestureRecognizer *gesture in [self.infoWindow.rootViewController.view.gestureRecognizers copy]) {
        [self.infoWindow.rootViewController.view removeGestureRecognizer:gesture];
    }
    
    self.infoWindow.hidden = YES;
}

#pragma mark - 视图高亮显示

- (void)highlightView:(UIView *)view {
    if (!view) return;
    
    [self removeHighlight];
    
    // 在窗口坐标系中获取视图的frame
    UIWindow *window = view.window;
    if (!window) {
        window = [UIApplication sharedApplication].keyWindow;
    }
    
    CGRect frameInWindow = [view convertRect:view.bounds toView:window];
    self.visualBorder.frame = frameInWindow;
    
    [window addSubview:self.visualBorder];
}

- (void)removeHighlight {
    [self.visualBorder removeFromSuperview];
}

#pragma mark - 视图属性检查

- (NSDictionary *)getViewProperties:(UIView *)view {
    if (!view) return @{};
    
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    // 基本属性
    properties[@"class"] = NSStringFromClass([view class]);
    properties[@"frame"] = NSStringFromCGRect(view.frame);
    properties[@"bounds"] = NSStringFromCGRect(view.bounds);
    properties[@"center"] = NSStringFromCGPoint(view.center);
    properties[@"transform"] = NSStringFromCGAffineTransform(view.transform);
    properties[@"alpha"] = @(view.alpha);
    properties[@"hidden"] = @(view.hidden);
    properties[@"opaque"] = @(view.opaque);
    properties[@"clipsToBounds"] = @(view.clipsToBounds);
    properties[@"backgroundColor"] = [self colorToString:view.backgroundColor];
    properties[@"tag"] = @(view.tag);
    
    // 层级关系
    properties[@"superview"] = view.superview ? NSStringFromClass([view.superview class]) : @"nil";
    properties[@"subviewCount"] = @(view.subviews.count);
    
    // 约束信息
    if (view.constraints.count > 0) {
        NSMutableArray *constraintDescriptions = [NSMutableArray array];
        for (NSLayoutConstraint *constraint in view.constraints) {
            [constraintDescriptions addObject:[constraint description]];
        }
        properties[@"constraints"] = constraintDescriptions;
    }
    
    return properties;
}

- (NSDictionary *)getViewConstraints:(UIView *)view {
    if (!view) return @{};
    
    NSMutableDictionary *constraints = [NSMutableDictionary dictionary];
    
    // 视图自身的约束
    NSMutableArray *ownConstraints = [NSMutableArray array];
    for (NSLayoutConstraint *constraint in view.constraints) {
        [ownConstraints addObject:[constraint description]];
    }
    constraints[@"ownConstraints"] = ownConstraints;
    
    // 影响此视图的约束
    if (view.superview) {
        NSMutableArray *superviewConstraints = [NSMutableArray array];
        for (NSLayoutConstraint *constraint in view.superview.constraints) {
            if (constraint.firstItem == view || constraint.secondItem == view) {
                [superviewConstraints addObject:[constraint description]];
            }
        }
        constraints[@"superviewConstraints"] = superviewConstraints;
    }
    
    return constraints;
}

- (NSDictionary *)getViewFrameInfo:(UIView *)view {
    if (!view) return @{};
    
    NSMutableDictionary *frameInfo = [NSMutableDictionary dictionary];
    
    // 基本尺寸信息
    frameInfo[@"frame"] = NSStringFromCGRect(view.frame);
    frameInfo[@"bounds"] = NSStringFromCGRect(view.bounds);
    frameInfo[@"center"] = NSStringFromCGPoint(view.center);
    
    // 在窗口中的位置
    UIWindow *window = view.window;
    if (window) {
        CGRect frameInWindow = [view convertRect:view.bounds toView:window];
        frameInfo[@"frameInWindow"] = NSStringFromCGRect(frameInWindow);
    }
    
    // 安全区域信息
    if (@available(iOS 11.0, *)) {
        UIEdgeInsets safeAreaInsets = view.safeAreaInsets;
        frameInfo[@"safeAreaInsets"] = NSStringFromUIEdgeInsets(safeAreaInsets);
    }
    
    return frameInfo;
}

#pragma mark - 视图截图

- (UIImage *)captureViewSnapshot:(UIView *)view {
    if (!view) return nil;
    
    // 直接使用iOS提供的截图方法
    if ([view respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)]) {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 0);
        [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return image;
    } else {
        // 旧方法的备选方案
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 0);
        CGContextRef context = UIGraphicsGetCurrentContext();
        [view.layer renderInContext:context];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return image;
    }
}

#pragma mark - 3D视图层次

- (void)show3DViewHierarchy:(UIView *)rootView {
    if (!rootView) return;
    
    // 创建一个新窗口来展示3D视图
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    window.windowLevel = UIWindowLevelAlert + 200;
    window.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    
    UIViewController *viewController = [[UIViewController alloc] init];
    window.rootViewController = viewController;
    
    // 添加手势用于关闭
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(close3DView:)];
    tapGesture.numberOfTapsRequired = 2;
    [viewController.view addGestureRecognizer:tapGesture];
    
    // 创建根视图的3D表示
    [self create3DRepresentationOfView:rootView inContainer:viewController.view];
    
    // 显示窗口
    window.hidden = NO;
    objc_setAssociatedObject(self, "3DWindow", window, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)create3DRepresentationOfView:(UIView *)view inContainer:(UIView *)container {
    // 为视图创建一个3D表示
    UIView *representation = [[UIView alloc] initWithFrame:view.frame];
    representation.backgroundColor = view.backgroundColor ?: [UIColor clearColor];
    representation.layer.borderWidth = 1.0;
    representation.layer.borderColor = [UIColor whiteColor].CGColor;
    
    // 添加标签显示类名
    UILabel *classLabel = [[UILabel alloc] init];
    classLabel.text = NSStringFromClass([view class]);
    classLabel.textColor = [UIColor whiteColor];
    classLabel.font = [UIFont systemFontOfSize:10];
    [classLabel sizeToFit];
    classLabel.center = CGPointMake(representation.bounds.size.width / 2, 10);
    [representation addSubview:classLabel];
    
    [container addSubview:representation];
    
    // 添加3D效果
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = -1.0 / 500.0; // 透视效果
    representation.layer.transform = CATransform3DRotate(transform, M_PI / 8, 1, 0, 0);
    
    // 递归处理子视图
    for (UIView *subview in view.subviews) {
        [self create3DRepresentationOfView:subview inContainer:representation];
    }
}

- (void)close3DView:(UITapGestureRecognizer *)gesture {
    UIWindow *window = objc_getAssociatedObject(self, "3DWindow");
    window.hidden = YES;
    objc_setAssociatedObject(self, "3DWindow", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 辅助方法

- (NSString *)colorToString:(UIColor *)color {
    if (!color) return @"nil";
    
    CGFloat red, green, blue, alpha;
    if ([color getRed:&red green:&green blue:&blue alpha:&alpha]) {
        return [NSString stringWithFormat:@"RGBA(%.2f, %.2f, %.2f, %.2f)", red, green, blue, alpha];
    }
    
    CGFloat white, alpha2;
    if ([color getWhite:&white alpha:&alpha2]) {
        return [NSString stringWithFormat:@"White(%.2f, %.2f)", white, alpha2];
    }
    
    return @"Unknown color format";
}

@end