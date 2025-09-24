#import "FLEXLookinInspector.h"
#import "FLEXUtility.h"
#import "FLEXCompatibility.h"
#import <QuartzCore/QuartzCore.h>

@interface FLEXLookinInspector ()
@property (nonatomic, strong) UIWindow *inspectorWindow;
@property (nonatomic, strong) UIViewController *hierarchyViewController;
@property (nonatomic, strong) NSMutableArray<FLEXLookinViewNode *> *viewNodes;
@property (nonatomic, assign, readwrite) BOOL isShowing;
@property (nonatomic, strong, readwrite) UIView *selectedView;
@property (nonatomic, strong) UIView *tempSelectedView;  // 临时变量，替代直接使用nil
@end

@implementation FLEXLookinInspector

+ (instancetype)sharedInstance {
    static FLEXLookinInspector *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _viewNodes = [NSMutableArray array];
        _isShowing = NO;
        _isInspecting = NO;
        _viewMode = FLEXLookinViewModeHierarchy;
    }
    return self;
}

- (void)inspectView:(UIView *)view {
    if (!view) {
        return;
    }
    
    [self.viewNodes removeAllObjects];
    [self buildViewHierarchy:view atDepth:0];
    
    if (!self.isShowing) {
        [self show3DHierarchy];
    } else {
        [self updateHierarchyDisplay];
    }
}

- (void)buildViewHierarchy:(UIView *)view atDepth:(NSInteger)depth {
    if (!view) {
        return;
    }
    
    // 创建视图节点
    FLEXLookinViewNode *node = [[FLEXLookinViewNode alloc] init];
    node.view = view;
    node.depth = depth;
    node.frame = view.frame;
    node.bounds = view.bounds;
    node.center = view.center;
    node.transform = view.transform;
    node.alpha = view.alpha;
    node.backgroundColor = view.backgroundColor;
    node.hidden = view.hidden;
    node.className = NSStringFromClass([view class]);
    
    // 计算在窗口中的坐标
    UIWindow *window = view.window;
    if (window) {
        node.frameInWindow = [view convertRect:view.bounds toView:window];
    } else {
        node.frameInWindow = view.frame;
    }
    
    [self.viewNodes addObject:node];
    
    // 递归处理子视图
    for (UIView *subview in view.subviews) {
        [self buildViewHierarchy:subview atDepth:depth + 1];
    }
}

- (void)show3DHierarchy {
    if (self.isShowing) {
        return;
    }
    
    self.isShowing = YES;
    
    // 创建检查器窗口
    self.inspectorWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.inspectorWindow.windowLevel = UIWindowLevelAlert + 1000;
    self.inspectorWindow.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    
    // 创建视图控制器
    self.hierarchyViewController = [[UIViewController alloc] init];
    self.inspectorWindow.rootViewController = self.hierarchyViewController;
    
    [self setupInspectorUI];
    [self updateHierarchyDisplay];
    
    // 显示窗口
    self.inspectorWindow.hidden = NO;
    if (@available(iOS 13.0, *)) {
        [self.inspectorWindow makeKeyAndVisible];
    } else {
        [self.inspectorWindow makeKeyAndVisible];
    }
}

- (void)setupInspectorUI {
    UIView *containerView = self.hierarchyViewController.view;
    containerView.backgroundColor = [UIColor clearColor];
    
    // 添加手势识别器
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] 
                                         initWithTarget:self 
                                         action:@selector(handlePanGesture:)];
    [containerView addGestureRecognizer:panGesture];
    
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] 
                                             initWithTarget:self 
                                             action:@selector(handlePinchGesture:)];
    [containerView addGestureRecognizer:pinchGesture];
    
    UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc] 
                                               initWithTarget:self 
                                               action:@selector(handleDoubleTapGesture:)];
    doubleTapGesture.numberOfTapsRequired = 2;
    [containerView addGestureRecognizer:doubleTapGesture];
    
    // 添加控制面板
    [self setupControlPanel];
}

- (void)setupControlPanel {
    UIView *controlPanel = [[UIView alloc] init];
    controlPanel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    controlPanel.layer.cornerRadius = 8;
    controlPanel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.hierarchyViewController.view addSubview:controlPanel];
    
    // 关闭按钮
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(hide3DHierarchy) forControlEvents:UIControlEventTouchUpInside];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [controlPanel addSubview:closeButton];
    
    // 重置按钮
    UIButton *resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [resetButton setTitle:@"重置" forState:UIControlStateNormal];
    [resetButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [resetButton addTarget:self action:@selector(resetHierarchyView) forControlEvents:UIControlEventTouchUpInside];
    resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    [controlPanel addSubview:resetButton];
    
    // 透明度滑块
    UISlider *alphaSlider = [[UISlider alloc] init];
    alphaSlider.minimumValue = 0.1;
    alphaSlider.maximumValue = 1.0;
    alphaSlider.value = 0.8;
    alphaSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [alphaSlider addTarget:self action:@selector(alphaSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [controlPanel addSubview:alphaSlider];
    
    UILabel *alphaLabel = [[UILabel alloc] init];
    alphaLabel.text = @"透明度";
    alphaLabel.textColor = [UIColor whiteColor];
    alphaLabel.font = [UIFont systemFontOfSize:14];
    alphaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [controlPanel addSubview:alphaLabel];
    
    // 布局约束
    NSLayoutYAxisAnchor *topAnchor;
    if (@available(iOS 11.0, *)) {
        topAnchor = self.hierarchyViewController.view.safeAreaLayoutGuide.topAnchor;
    } else {
        topAnchor = self.hierarchyViewController.view.topAnchor;
    }
    [NSLayoutConstraint activateConstraints:@[
        [controlPanel.topAnchor constraintEqualToAnchor:topAnchor constant:20],
        [controlPanel.leadingAnchor constraintEqualToAnchor:self.hierarchyViewController.view.leadingAnchor constant:20],
        [controlPanel.trailingAnchor constraintEqualToAnchor:self.hierarchyViewController.view.trailingAnchor constant:-20],
        [controlPanel.heightAnchor constraintEqualToConstant:80],
        
        [closeButton.topAnchor constraintEqualToAnchor:controlPanel.topAnchor constant:8],
        [closeButton.trailingAnchor constraintEqualToAnchor:controlPanel.trailingAnchor constant:-16],
        
        [resetButton.topAnchor constraintEqualToAnchor:controlPanel.topAnchor constant:8],
        [resetButton.trailingAnchor constraintEqualToAnchor:closeButton.leadingAnchor constant:-16],
        
        [alphaLabel.bottomAnchor constraintEqualToAnchor:controlPanel.bottomAnchor constant:-8],
        [alphaLabel.leadingAnchor constraintEqualToAnchor:controlPanel.leadingAnchor constant:16],
        
        [alphaSlider.bottomAnchor constraintEqualToAnchor:controlPanel.bottomAnchor constant:-8],
        [alphaSlider.leadingAnchor constraintEqualToAnchor:alphaLabel.trailingAnchor constant:16],
        [alphaSlider.trailingAnchor constraintEqualToAnchor:controlPanel.trailingAnchor constant:-16]
    ]];
}

- (void)updateHierarchyDisplay {
    // 清除之前的视图
    for (UIView *subview in self.hierarchyViewController.view.subviews) {
        if ([subview isKindOfClass:[UIView class]] && subview.tag == 9999) {
            [subview removeFromSuperview];
        }
    }
    
    // 创建3D视图表示
    for (FLEXLookinViewNode *node in self.viewNodes) {
        [self create3DRepresentationForNode:node];
    }
}

- (void)create3DRepresentationForNode:(FLEXLookinViewNode *)node {
    if (!node.view || node.hidden) {
        return;
    }
    
    // 创建3D视图容器
    UIView *representationView = [[UIView alloc] init];
    representationView.tag = 9999; // 标记为检查器视图
    representationView.layer.borderWidth = 1.0;
    representationView.layer.borderColor = [self borderColorForDepth:node.depth].CGColor;
    representationView.backgroundColor = [node.backgroundColor colorWithAlphaComponent:0.3] ?: [UIColor clearColor];
    
    // 应用3D变换
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = -1.0 / 500.0; // 透视效果
    transform = CATransform3DTranslate(transform, 0, 0, node.depth * 20); // Z轴偏移
    transform = CATransform3DRotate(transform, M_PI / 6, 1, 0, 0); // X轴旋转
    transform = CATransform3DRotate(transform, M_PI / 12, 0, 1, 0); // Y轴旋转
    
    representationView.layer.transform = transform;
    
    // 设置框架（考虑缩放）
    CGFloat scale = 0.8;
    CGRect scaledFrame = CGRectMake(
        node.frameInWindow.origin.x * scale,
        node.frameInWindow.origin.y * scale,
        node.frameInWindow.size.width * scale,
        node.frameInWindow.size.height * scale
    );
    representationView.frame = scaledFrame;
    
    // 添加标签显示类名
    UILabel *classLabel = [[UILabel alloc] init];
    classLabel.text = node.className;
    classLabel.font = [UIFont systemFontOfSize:10];
    classLabel.textColor = [UIColor whiteColor];
    classLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    classLabel.textAlignment = NSTextAlignmentCenter;
    [classLabel sizeToFit];
    classLabel.frame = CGRectMake(0, 0, MIN(classLabel.frame.size.width + 8, scaledFrame.size.width), 16);
    [representationView addSubview:classLabel];
    
    // 添加点击手势
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] 
                                         initWithTarget:self 
                                         action:@selector(handleViewTap:)];
    [representationView addGestureRecognizer:tapGesture];
    
    // 存储节点引用
    objc_setAssociatedObject(representationView, "viewNode", node, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self.hierarchyViewController.view addSubview:representationView];
}

- (UIColor *)borderColorForDepth:(NSInteger)depth {
    NSArray *colors = @[
        [UIColor redColor],
        [UIColor blueColor],
        [UIColor greenColor],
        [UIColor yellowColor],
        [UIColor magentaColor],
        [UIColor cyanColor],
        [UIColor orangeColor]
    ];
    
    return colors[depth % colors.count];
}

- (void)hide3DHierarchy {
    if (!self.isShowing) {
        return;
    }
    
    self.isShowing = NO;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.inspectorWindow.alpha = 0;
    } completion:^(BOOL finished) {
        self.inspectorWindow.hidden = YES;
        self.inspectorWindow = nil;
        self.hierarchyViewController = nil;
    }];
}

- (BOOL)isShowing3DHierarchy {
    return self.isShowing;
}

#pragma mark - Gesture Handlers

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:gesture.view];
    
    for (UIView *subview in self.hierarchyViewController.view.subviews) {
        if (subview.tag == 9999) {
            CGPoint center = subview.center;
            center.x += translation.x;
            center.y += translation.y;
            subview.center = center;
        }
    }
    
    [gesture setTranslation:CGPointZero inView:gesture.view];
}

- (void)handlePinchGesture:(UIPinchGestureRecognizer *)gesture {
    for (UIView *subview in self.hierarchyViewController.view.subviews) {
        if (subview.tag == 9999) {
            subview.transform = CGAffineTransformScale(subview.transform, gesture.scale, gesture.scale);
        }
    }
    
    gesture.scale = 1.0;
}

- (void)handleDoubleTapGesture:(UITapGestureRecognizer *)gesture {
    [self resetHierarchyView];
}

- (void)handleViewTap:(UITapGestureRecognizer *)gesture {
    FLEXLookinViewNode *node = objc_getAssociatedObject(gesture.view, "viewNode");
    if (node && node.view) {
        [self showViewDetails:node];
    }
}

- (void)resetHierarchyView {
    for (UIView *subview in self.hierarchyViewController.view.subviews) {
        if (subview.tag == 9999) {
            subview.transform = CGAffineTransformIdentity;
        }
    }
    
    [self updateHierarchyDisplay];
}

- (void)alphaSliderChanged:(UISlider *)slider {
    for (UIView *subview in self.hierarchyViewController.view.subviews) {
        if (subview.tag == 9999) {
            subview.alpha = slider.value;
        }
    }
}

- (void)showViewDetails:(FLEXLookinViewNode *)node {
    UIAlertController *alert = [UIAlertController 
                               alertControllerWithTitle:@"视图详情" 
                               message:[self detailStringForNode:node] 
                               preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" 
                                                      style:UIAlertActionStyleDefault 
                                                    handler:nil];
    [alert addAction:okAction];
    
    [self.hierarchyViewController presentViewController:alert animated:YES completion:nil];
}

- (NSString *)detailStringForNode:(FLEXLookinViewNode *)node {
    NSMutableString *details = [NSMutableString string];
    
    [details appendFormat:@"类名: %@\n", node.className];
    [details appendFormat:@"层级: %ld\n", (long)node.depth];
    [details appendFormat:@"Frame: %@\n", NSStringFromCGRect(node.frame)];
    [details appendFormat:@"Bounds: %@\n", NSStringFromCGRect(node.bounds)];
    [details appendFormat:@"Center: %@\n", NSStringFromCGPoint(node.center)];
    [details appendFormat:@"Alpha: %.2f\n", node.alpha];
    [details appendFormat:@"Hidden: %@\n", node.hidden ? @"YES" : @"NO"];
    
    if (node.backgroundColor) {
        [details appendFormat:@"背景色: %@\n", node.backgroundColor];
    }
    
    return details;
}

- (void)startInspecting {
    self.isInspecting = YES;
    [self refreshViewHierarchy];
}

- (void)stopInspecting {
    self.isInspecting = NO;
    // 使用临时视图或安全处理
    if (self.selectedView) {
        self.tempSelectedView = [[UIView alloc] init];
        self.selectedView = self.tempSelectedView;
    }
    [self hide3DHierarchy];
}

- (void)selectView:(UIView *)view {
    self.selectedView = view;
    
    // 通知代理
    if ([self.delegate respondsToSelector:@selector(lookinInspector:didSelectView:)]) {
        [self.delegate lookinInspector:self didSelectView:view];
    }
}

- (UIView *)selectedView {
    return _selectedView;
}

- (void)show3DViewHierarchy {
    [self show3DHierarchy];
}

- (void)refreshViewHierarchy {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    [self.viewNodes removeAllObjects];
    [self buildViewHierarchy:keyWindow atDepth:0];
    
    // 通知代理
    if ([self.delegate respondsToSelector:@selector(lookinInspector:didUpdateHierarchy:)]) {
        [self.delegate lookinInspector:self didUpdateHierarchy:[self flattenedHierarchy]];
    }
}

- (NSArray<FLEXLookinViewNode *> *)flattenedHierarchy {
    return [self.viewNodes copy];
}

@end

@implementation FLEXLookinViewNode

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> %@ depth:%ld frame:%@", 
            NSStringFromClass([self class]), self, self.className, (long)self.depth, NSStringFromCGRect(self.frame)];
}

@end