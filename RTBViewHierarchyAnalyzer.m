#import "RTBViewHierarchyAnalyzer.h"
#import <objc/runtime.h>

@implementation RTBViewNode
@end

@implementation RTBViewHierarchyAnalyzer

// 添加单例实现
+ (instancetype)sharedInstance {
    static RTBViewHierarchyAnalyzer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RTBViewHierarchyAnalyzer alloc] init];
    });
    return instance;
}

// 分析视图层次结构
- (RTBViewNode *)analyzeViewHierarchy:(UIView *)rootView {
    if (!rootView) {
        return nil;
    }
    
    RTBViewNode *rootNode = [[RTBViewNode alloc] init];
    rootNode.view = rootView;
    rootNode.depth = 0;
    rootNode.frame = rootView.frame;
    rootNode.className = NSStringFromClass([rootView class]);
    
    // 获取视图属性
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    properties[@"alpha"] = @(rootView.alpha);
    properties[@"hidden"] = @(rootView.hidden);
    properties[@"opaque"] = @(rootView.opaque);
    properties[@"userInteractionEnabled"] = @(rootView.userInteractionEnabled);
    properties[@"tag"] = @(rootView.tag);
    properties[@"backgroundColor"] = [self colorToString:rootView.backgroundColor];
    
    if ([rootView respondsToSelector:@selector(text)]) {
        properties[@"text"] = [rootView valueForKey:@"text"];
    }
    
    rootNode.properties = properties;
    
    // 递归处理子视图
    NSMutableArray *children = [NSMutableArray array];
    for (UIView *subview in rootView.subviews) {
        RTBViewNode *childNode = [self analyzeViewHierarchyWithDepth:subview depth:1];
        if (childNode) {
            [children addObject:childNode];
        }
    }
    
    rootNode.children = children;
    return rootNode;
}

// 辅助方法：递归分析视图层次
- (RTBViewNode *)analyzeViewHierarchyWithDepth:(UIView *)view depth:(NSInteger)depth {
    if (!view) {
        return nil;
    }
    
    RTBViewNode *node = [[RTBViewNode alloc] init];
    node.view = view;
    node.depth = depth;
    node.frame = view.frame;
    node.className = NSStringFromClass([view class]);
    
    // 获取视图属性
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    properties[@"alpha"] = @(view.alpha);
    properties[@"hidden"] = @(view.hidden);
    properties[@"opaque"] = @(view.opaque);
    properties[@"userInteractionEnabled"] = @(view.userInteractionEnabled);
    properties[@"tag"] = @(view.tag);
    properties[@"backgroundColor"] = [self colorToString:view.backgroundColor];
    
    if ([view respondsToSelector:@selector(text)]) {
        properties[@"text"] = [view valueForKey:@"text"];
    }
    
    node.properties = properties;
    
    // 递归处理子视图
    NSMutableArray *children = [NSMutableArray array];
    for (UIView *subview in view.subviews) {
        RTBViewNode *childNode = [self analyzeViewHierarchyWithDepth:subview depth:depth + 1];
        if (childNode) {
            [children addObject:childNode];
        }
    }
    
    node.children = children;
    return node;
}

// 颜色转字符串辅助方法
- (NSString *)colorToString:(UIColor *)color {
    if (!color) {
        return @"nil";
    }
    
    CGFloat red, green, blue, alpha;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    
    return [NSString stringWithFormat:@"RGB(%.2f, %.2f, %.2f, %.2f)", red * 255, green * 255, blue * 255, alpha];
}

// 查找深度超过指定值的视图
- (NSArray *)findViewsWithDepthGreaterThan:(NSInteger)maxDepth {
    NSMutableArray *result = [NSMutableArray array];
    
    // 获取根视图
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
                if (keyWindow) break;
            }
        }
    } else {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    
    if (!keyWindow) {
        return result;
    }
    
    [self findViewsWithDepthGreaterThan:maxDepth inView:keyWindow depth:0 result:result];
    return result;
}

// 递归查找深度超过指定值的视图
- (void)findViewsWithDepthGreaterThan:(NSInteger)maxDepth inView:(UIView *)view depth:(NSInteger)depth result:(NSMutableArray *)result {
    if (depth > maxDepth) {
        [result addObject:view];
    }
    
    for (UIView *subview in view.subviews) {
        [self findViewsWithDepthGreaterThan:maxDepth inView:subview depth:depth + 1 result:result];
    }
}

// 查找重叠视图
- (NSArray *)findOverlappingViews {
    NSMutableArray *result = [NSMutableArray array];
    
    // 获取根视图
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
                if (keyWindow) break;
            }
        }
    } else {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    
    if (!keyWindow) {
        return result;
    }
    
    [self findOverlappingViewsInView:keyWindow result:result];
    return result;
}

// 递归查找重叠视图
- (void)findOverlappingViewsInView:(UIView *)view result:(NSMutableArray *)result {
    NSArray *subviews = view.subviews;
    
    // 检查同一层级的视图是否重叠
    for (int i = 0; i < subviews.count; i++) {
        UIView *view1 = subviews[i];
        if (view1.hidden || view1.alpha < 0.1) continue;
        
        for (int j = i + 1; j < subviews.count; j++) {
            UIView *view2 = subviews[j];
            if (view2.hidden || view2.alpha < 0.1) continue;
            
            // 检查两个视图是否重叠
            if (CGRectIntersectsRect(view1.frame, view2.frame)) {
                // 计算重叠区域
                CGRect intersection = CGRectIntersection(view1.frame, view2.frame);
                CGFloat overlapArea = intersection.size.width * intersection.size.height;
                CGFloat view1Area = view1.frame.size.width * view1.frame.size.height;
                CGFloat view2Area = view2.frame.size.width * view2.frame.size.height;
                
                // 如果重叠面积超过较小视图面积的50%
                CGFloat smallerArea = MIN(view1Area, view2Area);
                if (overlapArea > smallerArea * 0.5) {
                    [result addObject:@{
                        @"view1": view1,
                        @"view2": view2,
                        @"overlapRatio": @(overlapArea / smallerArea)
                    }];
                }
            }
        }
    }
    
    // 递归检查子视图
    for (UIView *subview in subviews) {
        [self findOverlappingViewsInView:subview result:result];
    }
}

// 查找隐藏但仍在层次结构中的视图
- (NSArray *)findHiddenViews {
    NSMutableArray *result = [NSMutableArray array];
    
    // 获取根视图
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
                if (keyWindow) break;
            }
        }
    } else {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    
    if (!keyWindow) {
        return result;
    }
    
    [self findHiddenViewsInView:keyWindow result:result];
    return result;
}

// 递归查找隐藏视图
- (void)findHiddenViewsInView:(UIView *)view result:(NSMutableArray *)result {
    // 检查当前视图是否隐藏或完全透明
    if (view.hidden || view.alpha < 0.01) {
        [result addObject:view];
    }
    
    // 递归检查子视图
    for (UIView *subview in view.subviews) {
        [self findHiddenViewsInView:subview result:result];
    }
}

// 检测性能问题
- (NSArray *)detectPerformanceIssues:(UIView *)rootView {
    if (!rootView) {
        return @[];
    }
    
    NSMutableArray *issues = [NSMutableArray array];
    
    // 检查视图层次是否过深
    NSArray *deepViews = [self findViewsWithDepthGreaterThan:10];
    if (deepViews.count > 0) {
        [issues addObject:@{
            @"type": @"深层嵌套",
            @"description": @"视图层次过深可能导致性能问题",
            @"views": deepViews
        }];
    }
    
    // 检查重叠视图
    NSArray *overlappingViews = [self findOverlappingViews];
    if (overlappingViews.count > 0) {
        [issues addObject:@{
            @"type": @"视图重叠",
            @"description": @"重叠视图可能导致不必要的渲染",
            @"views": overlappingViews
        }];
    }
    
    // 检查隐藏视图
    NSArray *hiddenViews = [self findHiddenViews];
    if (hiddenViews.count > 10) {  // 只有当隐藏视图很多时才算问题
        [issues addObject:@{
            @"type": @"隐藏视图",
            @"description": @"大量隐藏视图仍在视图层次中",
            @"views": hiddenViews
        }];
    }
    
    // 检查大图片
    NSArray *largeImages = [self findLargeImages];
    if (largeImages.count > 0) {
        [issues addObject:@{
            @"type": @"大图片",
            @"description": @"大尺寸图片可能导致内存问题",
            @"views": largeImages
        }];
    }
    
    // 检查复杂绘制视图
    NSArray *complexViews = [self findComplexDrawingViews];
    if (complexViews.count > 0) {
        [issues addObject:@{
            @"type": @"复杂绘制",
            @"description": @"复杂绘制可能导致性能问题",
            @"views": complexViews
        }];
    }
    
    return issues;
}

// 查找大尺寸图片
- (NSArray *)findLargeImages {
    NSMutableArray *result = [NSMutableArray array];
    
    // 获取根视图
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
                if (keyWindow) break;
            }
        }
    } else {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    
    if (!keyWindow) {
        return result;
    }
    
    [self findLargeImagesInView:keyWindow result:result];
    return result;
}

// 递归查找大图片
- (void)findLargeImagesInView:(UIView *)view result:(NSMutableArray *)result {
    // 检查是否是 UIImageView
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        UIImage *image = imageView.image;
        
        if (image) {
            // 检查图片是否超过2MB或分辨率过高
            CGSize size = image.size;
            CGFloat bytesPerPixel = 4;  // RGBA
            CGFloat bytesPerRow = bytesPerPixel * size.width;
            CGFloat totalBytes = bytesPerRow * size.height;
            CGFloat totalMB = totalBytes / (1024 * 1024);
            
            if (totalMB > 2.0 || size.width > 2000 || size.height > 2000) {
                [result addObject:@{
                    @"view": imageView,
                    @"imageSize": NSStringFromCGSize(size),
                    @"memorySize": @(totalMB)
                }];
            }
        }
    }
    
    // 递归检查子视图
    for (UIView *subview in view.subviews) {
        [self findLargeImagesInView:subview result:result];
    }
}

// 查找使用复杂绘制的视图
- (NSArray *)findComplexDrawingViews {
    NSMutableArray *result = [NSMutableArray array];
    
    // 获取根视图
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
                if (keyWindow) break;
            }
        }
    } else {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    
    if (!keyWindow) {
        return result;
    }
    
    [self findComplexDrawingViewsInView:keyWindow result:result];
    return result;
}

// 递归查找复杂绘制视图
- (void)findComplexDrawingViewsInView:(UIView *)view result:(NSMutableArray *)result {
    // 检查视图是否覆盖了 drawRect: 方法
    Method originalMethod = class_getInstanceMethod([UIView class], @selector(drawRect:));
    Method overrideMethod = class_getInstanceMethod([view class], @selector(drawRect:));
    
    if (originalMethod != overrideMethod && ![view isKindOfClass:[UILabel class]]) {
        [result addObject:view];
    }
    
    // 递归检查子视图
    for (UIView *subview in view.subviews) {
        [self findComplexDrawingViewsInView:subview result:result];
    }
}

@end