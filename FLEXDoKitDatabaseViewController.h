#import "FLEXDoKitViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// 数据库浏览视图控制器，用于查看和操作SQLite数据库
@interface FLEXDoKitDatabaseViewController : FLEXDoKitViewController <UITableViewDataSource, UITableViewDelegate>

/// 当前浏览的数据库数组
@property (nonatomic, strong) NSArray<NSString *> *databases;

/// 当前选中的数据库文件路径
@property (nonatomic, copy, nullable) NSString *selectedDatabasePath;

/// 刷新数据库列表
- (void)refreshDatabases;

/// 显示数据库表详情
/// @param database 数据库路径
- (void)showTablesForDatabase:(NSString *)database;

/// 执行SQL查询
/// @param sql SQL语句
/// @param databasePath 数据库路径
/// @param completion 完成回调，包含结果或错误
- (void)executeSQL:(NSString *)sql 
   inDatabaseAtPath:(NSString *)databasePath 
        completion:(void (^)(NSArray * _Nullable results, NSError * _Nullable error))completion;

@end

@interface FLEXDoKitDatabaseTableViewController : FLEXDoKitViewController <UITableViewDataSource, UITableViewDelegate>

/// 数据库表名称
@property (nonatomic, copy) NSString *tableName;

/// 数据库路径
@property (nonatomic, copy) NSString *databasePath;

/// 表列信息
@property (nonatomic, strong) NSArray<NSDictionary *> *columns;

/// 表数据数组
@property (nonatomic, strong) NSArray<NSArray *> *tableData;

/// 初始化方法
/// @param tableName 表名
/// @param databasePath 数据库路径
- (instancetype)initWithTableName:(NSString *)tableName databasePath:(NSString *)databasePath;

/// 刷新表数据
- (void)refreshTableData;

/// 显示自定义SQL查询界面
- (void)showCustomSQLQuery;

@end

NS_ASSUME_NONNULL_END