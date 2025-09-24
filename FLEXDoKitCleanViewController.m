#import "FLEXDoKitCleanViewController.h"
#import "FLEXCompatibility.h"
#import "FLEXKeychainQuery.h"
#import <WebKit/WebKit.h>
#import <AVFoundation/AVFoundation.h>

@interface FLEXDoKitCleanViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSDictionary *> *cleanOptions;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *cacheSizes;
@end

@implementation FLEXDoKitCleanViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"缓存清理";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupTableView];
    [self setupCleanOptions];
    [self calculateCacheSizes];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = FLEXSystemBackgroundColor;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"CleanCell"];
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self)],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupCleanOptions {
    // 获取各种缓存目录路径
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = cachePaths.firstObject;
    
    NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = documentPaths.firstObject;
    
    NSString *tempDirectory = NSTemporaryDirectory();
    
    self.cleanOptions = @[
        @{
            @"title": @"清理应用缓存",
            @"detail": @"清理Caches目录",
            @"action": @"cleanCache",
            @"path": cacheDirectory,
            @"type": @"cache",
            @"destructive": @NO
        },
        @{
            @"title": @"清理Web缓存",
            @"detail": @"清理WebKit缓存数据",
            @"action": @"cleanWebCache",
            @"type": @"webCache",
            @"destructive": @NO
        },
        @{
            @"title": @"清理图片缓存",
            @"detail": @"清理SDWebImage等图片缓存",
            @"action": @"cleanImageCache",
            @"type": @"imageCache",
            @"destructive": @NO
        },
        @{
            @"title": @"清理临时文件",
            @"detail": @"清理tmp目录文件",
            @"action": @"cleanTempFiles",
            @"path": tempDirectory,
            @"type": @"temp",
            @"destructive": @NO
        },
        @{
            @"title": @"清理UserDefaults",
            @"detail": @"重置应用偏好设置",
            @"action": @"cleanUserDefaults",
            @"type": @"userDefaults",
            @"destructive": @YES
        },
        @{
            @"title": @"清理Keychain",
            @"detail": @"清理钥匙串数据",
            @"action": @"cleanKeychain",
            @"type": @"keychain",
            @"destructive": @YES
        },
        @{
            @"title": @"清理Documents",
            @"detail": @"清理Documents目录",
            @"action": @"cleanDocuments",
            @"path": documentDirectory,
            @"type": @"documents",
            @"destructive": @YES
        },
        @{
            @"title": @"清理数据库",
            @"detail": @"清理SQLite数据库文件",
            @"action": @"cleanDatabases",
            @"type": @"database",
            @"destructive": @YES
        },
        @{
            @"title": @"清理音视频缓存",
            @"detail": @"清理AVPlayer等媒体缓存",
            @"action": @"cleanMediaCache",
            @"type": @"mediaCache",
            @"destructive": @NO
        }
    ];
    
    [self.tableView reloadData];
}

- (void)calculateCacheSizes {
    self.cacheSizes = [NSMutableDictionary dictionary];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableDictionary *sizes = [NSMutableDictionary dictionary];
        
        for (NSDictionary *option in self.cleanOptions) {
            NSString *title = option[@"title"];
            NSString *type = option[@"type"];
            NSString *path = option[@"path"];
            
            if (path) {
                sizes[title] = @([self calculateDirectorySize:path]);
            } else if ([type isEqualToString:@"webCache"]) {
                sizes[title] = @([self calculateWebCacheSize]);
            } else if ([type isEqualToString:@"userDefaults"]) {
                sizes[title] = @([self calculateUserDefaultsSize]);
            } else if ([type isEqualToString:@"keychain"]) {
                sizes[title] = @([self calculateKeychainSize]);
            } else if ([type isEqualToString:@"imageCache"]) {
                sizes[title] = @([self calculateImageCacheSize]);
            } else if ([type isEqualToString:@"database"]) {
                sizes[title] = @([self calculateDatabaseSize]);
            } else if ([type isEqualToString:@"mediaCache"]) {
                sizes[title] = @([self calculateMediaCacheSize]);
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.cacheSizes = sizes;
            [self.tableView reloadData];
        });
    });
}

- (uint64_t)calculateDirectorySize:(NSString *)path {
    if (!path || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return 0;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:path];
    NSString *file;
    uint64_t totalSize = 0;
    
    while ((file = [enumerator nextObject])) {
        NSString *fullPath = [path stringByAppendingPathComponent:file];
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:nil];
        
        if (attributes) {
            NSString *fileType = attributes[NSFileType];
            if ([fileType isEqualToString:NSFileTypeRegular]) {
                totalSize += [attributes fileSize];
            }
        }
    }
    
    return totalSize;
}

- (uint64_t)calculateWebCacheSize {
    __block uint64_t totalSize = 0;
    
    if (@available(iOS 9.0, *)) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        WKWebsiteDataStore *dataStore = [WKWebsiteDataStore defaultDataStore];
        NSSet *dataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
        
        [dataStore fetchDataRecordsOfTypes:dataTypes completionHandler:^(NSArray<WKWebsiteDataRecord *> *records) {
            for (__unused WKWebsiteDataRecord *record in records) {
                // WKWebsiteDataRecord 没有直接的大小属性，使用估算值
                totalSize += 1024 * 1024; // 每个记录估算1MB
            }
            dispatch_semaphore_signal(semaphore);
        }];
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
    
    return totalSize;
}

- (uint64_t)calculateUserDefaultsSize {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *defaultsDict = [defaults dictionaryRepresentation];
    
    NSError *error = nil;
    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:defaultsDict
                                                                   format:NSPropertyListBinaryFormat_v1_0
                                                                  options:0
                                                                    error:&error];
    
    return error ? 0 : plistData.length;
}

- (uint64_t)calculateKeychainSize {
    // Keychain 大小难以精确计算，使用估算值
    FLEXKeychainQuery *query = [FLEXKeychainQuery new];
    query.service = [[NSBundle mainBundle] bundleIdentifier];
    
    NSArray *items = [query fetchAll:nil];
    return items.count * 1024; // 每个项目估算1KB
}

- (uint64_t)calculateImageCacheSize {
    uint64_t totalSize = 0;
    
    // 查找常见的图片缓存目录
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = cachePaths.firstObject;
    
    NSArray *imageCachePaths = @[
        [cacheDirectory stringByAppendingPathComponent:@"com.hackemist.SDWebImageCache.default"],
        [cacheDirectory stringByAppendingPathComponent:@"AFNetworking"],
        [cacheDirectory stringByAppendingPathComponent:@"Alamofire"],
        [cacheDirectory stringByAppendingPathComponent:@"Kingfisher"]
    ];
    
    for (NSString *path in imageCachePaths) {
        totalSize += [self calculateDirectorySize:path];
    }
    
    return totalSize;
}

- (uint64_t)calculateDatabaseSize {
    uint64_t totalSize = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // 搜索Documents和Library目录中的数据库文件
    NSArray *searchPaths = @[
        NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject,
        NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject
    ];
    
    for (NSString *searchPath in searchPaths) {
        NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:searchPath];
        NSString *file;
        
        while ((file = [enumerator nextObject])) {
            NSString *extension = [file pathExtension].lowercaseString;
            if ([extension isEqualToString:@"sqlite"] ||
                [extension isEqualToString:@"db"] ||
                [extension isEqualToString:@"sqlite3"] ||
                [extension isEqualToString:@"realm"]) {
                
                NSString *fullPath = [searchPath stringByAppendingPathComponent:file];
                NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:nil];
                if (attributes) {
                    totalSize += [attributes fileSize];
                }
            }
        }
    }
    
    return totalSize;
}

- (uint64_t)calculateMediaCacheSize {
    uint64_t totalSize = 0;
    
    // 查找媒体缓存目录
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = cachePaths.firstObject;
    
    NSArray *mediaCachePaths = @[
        [cacheDirectory stringByAppendingPathComponent:@"com.apple.avfoundation"],
        [cacheDirectory stringByAppendingPathComponent:@"MediaCache"],
        [cacheDirectory stringByAppendingPathComponent:@"VideoCache"]
    ];
    
    for (NSString *path in mediaCachePaths) {
        totalSize += [self calculateDirectorySize:path];
    }
    
    return totalSize;
}

- (NSString *)formattedSizeForOption:(NSString *)title {
    NSNumber *size = self.cacheSizes[title];
    if (size) {
        return [self formatFileSize:[size unsignedLongLongValue]];
    }
    return @"计算中...";
}

- (NSString *)formatFileSize:(unsigned long long)size {
    if (size == 0) return @"0 B";
    
    NSArray *units = @[@"B", @"KB", @"MB", @"GB", @"TB"];
    NSInteger unitIndex = 0;
    double fileSize = (double)size;
    
    while (fileSize >= 1024.0 && unitIndex < units.count - 1) {
        fileSize /= 1024.0;
        unitIndex++;
    }
    
    if (unitIndex == 0) {
        return [NSString stringWithFormat:@"%.0f %@", fileSize, units[unitIndex]];
    } else {
        return [NSString stringWithFormat:@"%.2f %@", fileSize, units[unitIndex]];
    }
}

#pragma mark - Clean Actions

- (void)cleanCache {
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = cachePaths.firstObject;
    [self cleanDirectory:cacheDirectory withName:@"缓存"];
}

- (void)cleanWebCache {
    if (@available(iOS 9.0, *)) {
        WKWebsiteDataStore *dataStore = [WKWebsiteDataStore defaultDataStore];
        NSSet *dataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
        NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
        
        [dataStore removeDataOfTypes:dataTypes modifiedSince:dateFrom completionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showSuccessAlert:@"Web缓存已清理"];
                [self calculateCacheSizes];
            });
        }];
    } else {
        // iOS 9.0 以下版本的处理
        NSURLCache *cache = [NSURLCache sharedURLCache];
        [cache removeAllCachedResponses];
        [self showSuccessAlert:@"Web缓存已清理"];
        [self calculateCacheSizes];
    }
}

- (void)cleanImageCache {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cacheDirectory = cachePaths.firstObject;
        
        NSArray *imageCachePaths = @[
            [cacheDirectory stringByAppendingPathComponent:@"com.hackemist.SDWebImageCache.default"],
            [cacheDirectory stringByAppendingPathComponent:@"AFNetworking"],
            [cacheDirectory stringByAppendingPathComponent:@"Alamofire"],
            [cacheDirectory stringByAppendingPathComponent:@"Kingfisher"]
        ];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSUInteger totalDeleted = 0;
        
        for (NSString *path in imageCachePaths) {
            if ([fileManager fileExistsAtPath:path]) {
                NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:nil];
                for (NSString *file in contents) {
                    NSString *filePath = [path stringByAppendingPathComponent:file];
                    if ([fileManager removeItemAtPath:filePath error:nil]) {
                        totalDeleted++;
                    }
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showSuccessAlert:[NSString stringWithFormat:@"图片缓存已清理，删除了%lu个文件", (unsigned long)totalDeleted]];
            [self calculateCacheSizes];
        });
    });
}

- (void)cleanTempFiles {
    NSString *tempDirectory = NSTemporaryDirectory();
    [self cleanDirectory:tempDirectory withName:@"临时文件"];
}

- (void)cleanUserDefaults {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认清理" 
                                                                   message:@"此操作将重置所有应用偏好设置，是否继续？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
        for (NSString *key in defaults.allKeys) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self showSuccessAlert:@"UserDefaults已清理"];
        [self calculateCacheSizes];
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)cleanKeychain {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认清理" 
                                                                   message:@"此操作将删除应用的钥匙串数据，是否继续？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self performKeychainCleanup];
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performKeychainCleanup {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        FLEXKeychainQuery *query = [FLEXKeychainQuery new];
        query.service = [[NSBundle mainBundle] bundleIdentifier];
        
        NSArray *items = [query fetchAll:nil];
        NSUInteger deletedCount = 0;
        
        for (NSDictionary *item in items) {
            NSString *account = item[(__bridge NSString *)kSecAttrAccount];
            if (account) {
                query.account = account;
                if ([query deleteItem:nil]) {
                    deletedCount++;
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showSuccessAlert:[NSString stringWithFormat:@"Keychain已清理，删除了%lu个项目", (unsigned long)deletedCount]];
            [self calculateCacheSizes];
        });
    });
}

- (void)cleanDocuments {
    NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = documentPaths.firstObject;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"危险操作" 
                                                                   message:@"此操作将删除Documents目录所有文件，是否继续？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self cleanDirectory:documentDirectory withName:@"Documents"];
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)cleanDatabases {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"危险操作" 
                                                                   message:@"此操作将删除所有数据库文件，可能导致数据丢失，是否继续？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self performDatabaseCleanup];
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performDatabaseCleanup {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSUInteger deletedCount = 0;
        
        NSArray *searchPaths = @[
            NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject,
            NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject
        ];
        
        for (NSString *searchPath in searchPaths) {
            NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:searchPath];
            NSString *file;
            
            while ((file = [enumerator nextObject])) {
                NSString *extension = [file pathExtension].lowercaseString;
                if ([extension isEqualToString:@"sqlite"] ||
                    [extension isEqualToString:@"db"] ||
                    [extension isEqualToString:@"sqlite3"] ||
                    [extension isEqualToString:@"realm"]) {
                    
                    NSString *fullPath = [searchPath stringByAppendingPathComponent:file];
                    if ([fileManager removeItemAtPath:fullPath error:nil]) {
                        deletedCount++;
                    }
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showSuccessAlert:[NSString stringWithFormat:@"数据库文件已清理，删除了%lu个文件", (unsigned long)deletedCount]];
            [self calculateCacheSizes];
        });
    });
}

- (void)cleanMediaCache {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cacheDirectory = cachePaths.firstObject;
        
        NSArray *mediaCachePaths = @[
            [cacheDirectory stringByAppendingPathComponent:@"com.apple.avfoundation"],
            [cacheDirectory stringByAppendingPathComponent:@"MediaCache"],
            [cacheDirectory stringByAppendingPathComponent:@"VideoCache"]
        ];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSUInteger totalDeleted = 0;
        
        for (NSString *path in mediaCachePaths) {
            if ([fileManager fileExistsAtPath:path]) {
                NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:nil];
                for (NSString *file in contents) {
                    NSString *filePath = [path stringByAppendingPathComponent:file];
                    if ([fileManager removeItemAtPath:filePath error:nil]) {
                        totalDeleted++;
                    }
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showSuccessAlert:[NSString stringWithFormat:@"音视频缓存已清理，删除了%lu个文件", (unsigned long)totalDeleted]];
            [self calculateCacheSizes];
        });
    });
}

- (void)cleanDirectory:(NSString *)directoryPath withName:(NSString *)name {
    if (!directoryPath || ![[NSFileManager defaultManager] fileExistsAtPath:directoryPath]) {
        [self showAlert:@"错误" message:[NSString stringWithFormat:@"%@目录不存在", name]];
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        NSArray *contents = [fileManager contentsOfDirectoryAtPath:directoryPath error:&error];
        
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showAlert:@"错误" message:[NSString stringWithFormat:@"读取%@目录失败: %@", name, error.localizedDescription]];
            });
            return;
        }
        
        NSUInteger totalFiles = 0;
        NSUInteger deletedFiles = 0;
        unsigned long long totalSize = 0;
        unsigned long long deletedSize = 0;
        
        for (NSString *item in contents) {
            NSString *fullPath = [directoryPath stringByAppendingPathComponent:item];
            
            // 获取文件属性
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:nil];
            unsigned long long fileSize = [attributes fileSize];
            totalSize += fileSize;
            totalFiles++;
            
            // 删除文件或目录
            BOOL success = [fileManager removeItemAtPath:fullPath error:&error];
            if (success) {
                deletedFiles++;
                deletedSize += fileSize;
            } else {
                NSLog(@"删除失败 %@: %@", fullPath, error.localizedDescription);
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *message = [NSString stringWithFormat:@"%@清理完成\n删除文件: %lu/%lu\n释放空间: %@/%@", 
                               name, (unsigned long)deletedFiles, (unsigned long)totalFiles,
                               [self formatFileSize:deletedSize], [self formatFileSize:totalSize]];
            [self showAlert:@"清理完成" message:message];
            [self calculateCacheSizes];
        });
    });
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title 
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSuccessAlert:(NSString *)message {
    [self showAlert:@"成功" message:message];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.cleanOptions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CleanCell" forIndexPath:indexPath];
    
    NSDictionary *option = self.cleanOptions[indexPath.row];
    NSString *title = option[@"title"];
    NSString *detail = option[@"detail"];
    BOOL isDestructive = [option[@"destructive"] boolValue];
    
    cell.textLabel.text = title;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@", detail, [self formattedSizeForOption:title]];
    
    // 危险操作使用红色文字
    if (isDestructive) {
        cell.textLabel.textColor = FLEXSystemRedColor;
    } else {
        cell.textLabel.textColor = FLEXLabelColor;
    }
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *option = self.cleanOptions[indexPath.row];
    NSString *action = option[@"action"];
    
    if ([self respondsToSelector:NSSelectorFromString(action)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:NSSelectorFromString(action)];
#pragma clang diagnostic pop
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"可清理项目";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"注意：红色项目为危险操作，可能导致数据丢失，请谨慎操作。";
}

@end