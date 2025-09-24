#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class FLEXLookinViewNode;
@class FLEXLookinInspector;

// 添加缺失的视图模式枚举
typedef NS_ENUM(NSInteger, FLEXLookinViewMode) {
    FLEXLookinViewModeHierarchy = 0,
    FLEXLookinViewMode3D = 1
};

// 添加缺失的代理协议
@protocol FLEXLookinInspectorDelegate <NSObject>
@optional
- (void)lookinInspector:(FLEXLookinInspector *)inspector didSelectView:(UIView *)view;
- (void)lookinInspector:(FLEXLookinInspector *)inspector didUpdateHierarchy:(NSArray<FLEXLookinViewNode *> *)hierarchy;
@end

/// 3D视图层次检查器，类似Lookin工具的功能
@interface FLEXLookinInspector : NSObject

/// 代理对象
@property (nonatomic, assign) id<FLEXLookinInspectorDelegate> delegate;

/// 当前视图模式
@property (nonatomic, assign) FLEXLookinViewMode viewMode;

/// 是否正在检查
@property (nonatomic, assign) BOOL isInspecting;

/// 是否正在显示
@property (nonatomic, assign, readonly) BOOL isShowing;

/// 选中的视图（只读）
@property (nonatomic, strong, readonly) UIView *selectedView;

/// 选中的视图（内部可变）- 添加此属性
@property (nonatomic, strong) UIView *mutableSelectedView;

/// 共享实例
+ (instancetype)sharedInstance;

/// 检查指定视图的层次结构
/// @param view 要检查的根视图
- (void)inspectView:(UIView *)view;

/// 开始检查
- (void)startInspecting;

/// 停止检查
- (void)stopInspecting;

/// 选择视图
- (void)selectView:(UIView *)view;

/// 显示3D层次结构
- (void)show3DViewHierarchy;

/// 显示3D视图
- (void)show3DHierarchy;

/// 隐藏3D层次结构
- (void)hide3DHierarchy;

/// 刷新视图层次
- (void)refreshViewHierarchy;

/// 获取扁平化的层次结构
- (NSArray<FLEXLookinViewNode *> *)flattenedHierarchy;

/// 是否正在显示3D层次结构
- (BOOL)isShowing3DHierarchy;

@end

/// 视图节点，表示视图层次中的一个节点
@interface FLEXLookinViewNode : NSObject

/// 关联的视图
@property (nonatomic, assign) UIView *view;

/// 层次深度
@property (nonatomic, assign) NSInteger depth;

/// 视图框架
@property (nonatomic, assign) CGRect frame;

/// 视图边界
@property (nonatomic, assign) CGRect bounds;

/// 视图中心点
@property (nonatomic, assign) CGPoint center;

/// 视图变换
@property (nonatomic, assign) CGAffineTransform transform;

/// 透明度
@property (nonatomic, assign) CGFloat alpha;

/// 背景色
@property (nonatomic, strong, nullable) UIColor *backgroundColor;

/// 是否隐藏
@property (nonatomic, assign) BOOL hidden;

/// 类名
@property (nonatomic, copy) NSString *className;

/// 在窗口中的框架
@property (nonatomic, assign) CGRect frameInWindow;

@end

NS_ASSUME_NONNULL_END