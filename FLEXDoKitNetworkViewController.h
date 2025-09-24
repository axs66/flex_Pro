#import "FLEXDoKitViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// 网络监控视图控制器，用于监控和显示应用程序的网络请求
@interface FLEXDoKitNetworkViewController : FLEXDoKitViewController <UITableViewDataSource, UITableViewDelegate>

/// 分段控制器，用于筛选不同类型的网络请求
@property (nonatomic, strong) UISegmentedControl *segmentedControl;

/// 网络请求列表
@property (nonatomic, copy) NSArray<NSDictionary *> *networkRequests;

/// 刷新网络请求数据
- (void)refreshData;

/// 清除所有网络请求记录
- (void)clearLogs;

/// 显示网络设置界面
- (void)showSettings;

/// 显示Mock数据设置界面
- (void)showMockSettings;

/// 显示弱网模拟设置界面
- (void)showSlowNetworkSettings;

/// 显示请求详情
/// @param request 请求信息字典
- (void)showRequestDetail:(NSDictionary *)request;

/// 在详情视图中添加信息部分
/// @param title 部分标题
/// @param content 部分内容
/// @param stackView 目标堆栈视图
- (void)addDetailSection:(NSString *)title content:(nullable NSString *)content toStackView:(UIStackView *)stackView;

@end

NS_ASSUME_NONNULL_END