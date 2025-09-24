#import "FLEXDoKitViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// 日志查看视图控制器，用于展示和过滤应用程序日志
@interface FLEXDoKitLogViewController : FLEXDoKitViewController

/// 刷新日志内容
- (void)refreshLogs;

/// 清除所有日志
- (void)clearLogs;

/// 显示设置菜单
- (void)showSettings;

/// 分享当前过滤的日志
- (void)shareLogs;

@end

NS_ASSUME_NONNULL_END