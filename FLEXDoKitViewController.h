#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// DoKit模块视图控制器的基类，提供通用功能和一致外观
@interface FLEXDoKitViewController : UIViewController

/// 设置控制器基本UI
- (void)setupBasicUI;

/// 表格视图（如果控制器基于表格视图）
@property (nonatomic, strong, readonly, nullable) UITableView *tableView;

/// 刷新控件（如果使用）
@property (nonatomic, strong, readonly, nullable) UIRefreshControl *refreshControl;

/// 显示加载指示器
- (void)showLoading;

/// 隐藏加载指示器
- (void)hideLoading;

/// 显示错误信息
- (void)showError:(NSString *)message;

/// 显示成功信息
- (void)showSuccess:(NSString *)message;

/// 显示警告信息
- (void)showWarning:(NSString *)message;

/// 添加右上角关闭按钮
- (void)addCloseButton;

/// 添加右上角设置按钮
- (void)addSettingsButton;

/// 添加刷新控件到表格视图
- (void)addRefreshControl;

/// 添加搜索控制器
- (void)addSearchController;

@end

NS_ASSUME_NONNULL_END