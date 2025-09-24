#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RTBViewInspector : NSObject

// 视图检查功能
+ (instancetype)sharedInspector;

// 视图层次结构相关
- (void)inspectViewHierarchy:(UIView *)rootView;
- (void)highlightView:(UIView *)view;
- (void)removeHighlight;

// 视图属性检查
- (NSDictionary *)getViewProperties:(UIView *)view;
- (NSDictionary *)getViewConstraints:(UIView *)view;
- (NSDictionary *)getViewFrameInfo:(UIView *)view;

// 视图截图
- (UIImage *)captureViewSnapshot:(UIView *)view;

// 3D视图层次
- (void)show3DViewHierarchy:(UIView *)rootView;

@end

NS_ASSUME_NONNULL_END