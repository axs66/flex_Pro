#import "FLEXDoKitDatabaseViewController.h"
#import "FLEXCompatibility.h"
#import <sqlite3.h>

@interface FLEXDoKitDatabaseViewController () <UITableViewDataSource, UITableViewDelegate>
// 使用不同名称的属性
@property (nonatomic, strong) UITableView *dbTableView;
@property (nonatomic, strong) NSMutableArray<NSString *> *databaseFiles;
@end

@implementation FLEXDoKitDatabaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"数据库查看";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    self.databaseFiles = [NSMutableArray new];
    [self scanForDatabases];
    [self setupTableView];
}

- (void)setupTableView {
    // 使用自己的表格视图属性
    self.dbTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.dbTableView.backgroundColor = FLEXSystemBackgroundColor;
    self.dbTableView.delegate = self;
    self.dbTableView.dataSource = self;
    [self.dbTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"DatabaseCell"];
    
    self.dbTableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.dbTableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.dbTableView.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self)],
        [self.dbTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.dbTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.dbTableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

// 修改相关方法中使用的表格视图引用
- (void)refreshDatabases {
    [self.databaseFiles removeAllObjects];
    [self scanForDatabases];
    [self.dbTableView reloadData]; // 使用dbTableView替代tableView
}

// 实现缺失的方法
- (void)showTablesForDatabase:(NSString *)database {
    // 打开数据库并列出表格
    sqlite3 *db = NULL;
    sqlite3_stmt *statement = NULL;
    NSMutableArray *tables = [NSMutableArray array];
    
    @try {
        // 打开数据库
        int result = sqlite3_open([database UTF8String], &db);
        if (result != SQLITE_OK) {
            NSString *errorMsg = [NSString stringWithUTF8String:sqlite3_errmsg(db)];
            [self showAlert:@"打开数据库失败" message:errorMsg];
            return;
        }
        
        // 查询表格
        const char *sql = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name";
        result = sqlite3_prepare_v2(db, sql, -1, &statement, NULL);
        
        if (result != SQLITE_OK) {
            NSString *errorMsg = [NSString stringWithUTF8String:sqlite3_errmsg(db)];
            [self showAlert:@"查询表格失败" message:errorMsg];
            return;
        }
        
        // 获取表格
        while (sqlite3_step(statement) == SQLITE_ROW) {
            char *nameChars = (char *)sqlite3_column_text(statement, 0);
            if (nameChars) {
                NSString *tableName = [NSString stringWithUTF8String:nameChars];
                if (tableName && tableName.length > 0) {
                    [tables addObject:tableName];
                }
            }
        }
        
        [self showTablesForDatabase:database tables:tables];
        
    } @catch (NSException *exception) {
        [self showAlert:@"数据库异常" message:exception.reason];
    } @finally {
        if (statement) {
            sqlite3_finalize(statement);
        }
        if (db) {
            sqlite3_close(db);
        }
    }
}

- (void)executeSQL:(NSString *)sql 
   inDatabaseAtPath:(NSString *)databasePath 
        completion:(void (^)(NSArray * _Nullable results, NSError * _Nullable error))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sqlite3 *db = NULL;
        sqlite3_stmt *statement = NULL;
        NSMutableArray *results = [NSMutableArray array];
        NSError *error = nil;
        
        @try {
            // 打开数据库
            int result = sqlite3_open([databasePath UTF8String], &db);
            if (result != SQLITE_OK) {
                NSString *errorMsg = [NSString stringWithUTF8String:sqlite3_errmsg(db)];
                error = [NSError errorWithDomain:@"FLEXDoKit" code:result userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(nil, error);
                });
                return;
            }
            
            // 准备SQL语句
            result = sqlite3_prepare_v2(db, [sql UTF8String], -1, &statement, NULL);
            if (result != SQLITE_OK) {
                NSString *errorMsg = [NSString stringWithUTF8String:sqlite3_errmsg(db)];
                error = [NSError errorWithDomain:@"FLEXDoKit" code:result userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(nil, error);
                });
                return;
            }
            
            // 获取列名
            int columnCount = sqlite3_column_count(statement);
            NSMutableArray *columnNames = [NSMutableArray array];
            
            for (int i = 0; i < columnCount; i++) {
                const char *name = sqlite3_column_name(statement, i);
                [columnNames addObject:[NSString stringWithUTF8String:name]];
            }
            
            [results addObject:columnNames];
            
            // 执行查询
            while (sqlite3_step(statement) == SQLITE_ROW) {
                NSMutableArray *row = [NSMutableArray array];
                
                for (int i = 0; i < columnCount; i++) {
                    int columnType = sqlite3_column_type(statement, i);
                    id value = nil;
                    
                    switch (columnType) {
                        case SQLITE_INTEGER:
                            value = @(sqlite3_column_int64(statement, i));
                            break;
                            
                        case SQLITE_FLOAT:
                            value = @(sqlite3_column_double(statement, i));
                            break;
                            
                        case SQLITE_TEXT: {
                            const char *text = (const char *)sqlite3_column_text(statement, i);
                            value = text ? [NSString stringWithUTF8String:text] : @"";
                            break;
                        }
                            
                        case SQLITE_BLOB: {
                            const void *blob = sqlite3_column_blob(statement, i);
                            int size = sqlite3_column_bytes(statement, i);
                            value = [NSData dataWithBytes:blob length:size];
                            break;
                        }
                            
                        case SQLITE_NULL:
                        default:
                            value = [NSNull null];
                            break;
                    }
                    
                    [row addObject:value ?: [NSNull null]];
                }
                
                [results addObject:row];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(results, nil);
            });
            
        } @catch (NSException *exception) {
            error = [NSError errorWithDomain:@"FLEXDoKit" code:0 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"未知异常"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
        } @finally {
            if (statement) {
                sqlite3_finalize(statement);
            }
            if (db) {
                sqlite3_close(db);
            }
        }
    });
}

// 辅助方法
- (void)scanForDatabases {
    NSArray *paths = @[
        // 沙盒路径
        NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject,
        NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject,
        NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject,
        NSTemporaryDirectory()
    ];
    
    for (NSString *path in paths) {
        [self findDatabasesInDirectory:path];
    }
}

- (void)findDatabasesInDirectory:(NSString *)directory {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:directory error:&error];
    
    if (error) {
        NSLog(@"读取目录失败: %@", error.localizedDescription);
        return;
    }
    
    for (NSString *item in contents) {
        NSString *fullPath = [directory stringByAppendingPathComponent:item];
        BOOL isDirectory = NO;
        
        if ([fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory]) {
            if (isDirectory) {
                // 递归检查子目录
                [self findDatabasesInDirectory:fullPath];
            } else {
                // 检查是否是SQLite数据库文件
                if ([item.pathExtension.lowercaseString isEqualToString:@"db"] ||
                    [item.pathExtension.lowercaseString isEqualToString:@"sqlite"] ||
                    [item.pathExtension.lowercaseString isEqualToString:@"sqlite3"]) {
                    [self.databaseFiles addObject:fullPath];
                }
            }
        }
    }
}

- (void)showTablesForDatabase:(NSString *)databasePath tables:(NSArray *)tables {
    NSString *message;
    
    if (tables.count == 0) {
        message = @"数据库中没有找到表";
    } else {
        message = [NSString stringWithFormat:@"数据库包含 %lu 个表:\n%@", 
                  (unsigned long)tables.count, [tables componentsJoinedByString:@"\n"]];
    }
    
    [self showAlert:@"数据库表" message:message];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title 
                                                                 message:message
                                                          preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.databaseFiles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DatabaseCell" forIndexPath:indexPath];
    
    NSString *databasePath = self.databaseFiles[indexPath.row];
    cell.textLabel.text = [databasePath lastPathComponent];
    cell.detailTextLabel.text = databasePath;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *databasePath = self.databaseFiles[indexPath.row];
    [self showTablesForDatabase:databasePath];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [NSString stringWithFormat:@"找到 %lu 个数据库文件", (unsigned long)self.databaseFiles.count];
}

@end