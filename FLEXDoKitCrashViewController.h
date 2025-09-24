#import "FLEXDoKitViewController.h"
#import "FLEXDoKitCrashRecord.h"

NS_ASSUME_NONNULL_BEGIN

/// 崩溃记录查看控制器，显示和管理应用程序的崩溃记录
@interface FLEXDoKitCrashViewController : FLEXDoKitViewController <UITableViewDataSource, UITableViewDelegate>

/// 崩溃记录列表
@property (nonatomic, strong) NSArray<FLEXDoKitCrashRecord *> *crashRecords;

/// 自定义表格视图，用于展示崩溃记录 - 重命名避免与父类属性冲突
@property (nonatomic, strong) UITableView *crashTableView;

/// 加载崩溃记录
- (void)refreshCrashRecords;

/// 清除所有崩溃记录
- (void)clearCrashRecords;

/// 提示用户确认清除崩溃记录
- (void)promptToClearCrashRecords;

/// 显示崩溃详情
/// @param record 崩溃记录对象
- (void)showCrashDetail:(FLEXDoKitCrashRecord *)record;

@end

NS_ASSUME_NONNULL_END