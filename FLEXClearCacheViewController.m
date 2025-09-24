//
//  FLEXClearCacheViewController.m
//  FLEX
//
//  Created for DoKit integration
//

#import "FLEXClearCacheViewController.h"
#import "FLEXUtility.h"
#import "FLEXAlert.h"
#import <WebKit/WebKit.h>

@interface FLEXClearCacheViewController ()

@property (nonatomic, strong) NSArray *cacheOptions;
@property (nonatomic, strong) NSMutableDictionary *cacheSizes;

- (uint64_t)estimateWebCacheSize;
- (uint64_t)estimateImageCacheSize;
- (uint64_t)estimateUserDefaultsSize;

@end

@implementation FLEXClearCacheViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"清除本地数据";
    
    // 配置缓存选项
    self.cacheOptions = @[
        @{@"title": @"应用缓存", @"path": NSTemporaryDirectory(), @"type": @"temp"},
        @{@"title": @"用户偏好", @"type": @"userDefaults"},
        @{@"title": @"Cookies", @"type": @"cookies"},
        @{@"title": @"Keychain数据", @"type": @"keychain"},
    ];
    
    self.cacheSizes = [NSMutableDictionary dictionary];
    
    // 在后台计算缓存大小
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self calculateCacheSizes];
    });
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"CacheCell"];
}

- (void)calculateCacheSizes {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableDictionary *sizes = [NSMutableDictionary dictionary];
        
        for (NSDictionary *option in self.cacheOptions) {
            NSString *type = option[@"type"];
            NSString *title = option[@"title"];
            
            if ([type isEqualToString:@"temp"] || [type isEqualToString:@"cache"]) {
                NSString *path = option[@"path"];
                sizes[title] = @([self calculateDirectorySize:path]);
            } else if ([type isEqualToString:@"webCache"]) {
                sizes[title] = @([self estimateWebCacheSize]);
            } else if ([type isEqualToString:@"imageCache"]) {
                sizes[title] = @([self estimateImageCacheSize]);
            } else if ([type isEqualToString:@"userDefaults"]) {
                sizes[title] = @([self estimateUserDefaultsSize]);
            } else if ([type isEqualToString:@"keychain"]) {
                sizes[title] = @(10 * 1024); // 估算值
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.cacheSizes = sizes;
            [self.tableView reloadData];
        });
    });
}

- (uint64_t)calculateDirectorySize:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:nil];
    
    uint64_t totalSize = 0;
    for (NSString *name in contents) {
        NSString *fullPath = [path stringByAppendingPathComponent:name];
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory]) {
            if (isDirectory) {
                totalSize += [self calculateDirectorySize:fullPath];
            } else {
                NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:nil];
                totalSize += [attributes fileSize];
            }
        }
    }
    
    return totalSize;
}

- (NSString *)formattedSizeForOption:(NSString *)title {
    NSNumber *size = self.cacheSizes[title];
    if (size) {
        uint64_t bytes = [size unsignedLongLongValue];
        if (bytes < 1024) {
            return [NSString stringWithFormat:@"%llu B", bytes];
        } else if (bytes < 1024 * 1024) {
            return [NSString stringWithFormat:@"%.2f KB", (double)bytes / 1024];
        } else {
            return [NSString stringWithFormat:@"%.2f MB", (double)bytes / (1024 * 1024)];
        }
    }
    return @"计算中...";
}

- (void)clearCache:(NSDictionary *)option {
    NSString *type = option[@"type"];
    
    if ([type isEqualToString:@"temp"]) {
        NSString *path = option[@"path"];
        [self clearDirectoryContents:path];
    } else if ([type isEqualToString:@"cache"]) {
        NSString *path = option[@"path"];
        [self clearDirectoryContents:path];
    } else if ([type isEqualToString:@"webCache"]) {
        [self clearWebCache];
    } else if ([type isEqualToString:@"imageCache"]) {
        [self clearImageCache];
    } else if ([type isEqualToString:@"userDefaults"]) {
        [self clearUserDefaults];
    } else if ([type isEqualToString:@"keychain"]) {
        [self clearKeychain];
    }
    
    // 重新计算大小
    [self calculateCacheSizes];
}

- (void)clearDirectoryContents:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:nil];
    
    NSUInteger clearedCount = 0;
    uint64_t clearedSize = 0;
    
    for (NSString *item in contents) {
        NSString *fullPath = [path stringByAppendingPathComponent:item];
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:nil];
        uint64_t itemSize = [attributes fileSize];
        
        NSError *error;
        BOOL success = [fileManager removeItemAtPath:fullPath error:&error];
        if (success) {
            clearedCount++;
            clearedSize += itemSize;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *message = [NSString stringWithFormat:@"已清理 %lu 个文件，释放 %@", 
                            (unsigned long)clearedCount, [self formatBytes:clearedSize]];
        [self showSuccessAlert:message];
    });
}

- (void)clearWebCache {
    // 清理 WKWebView 缓存
    if (@available(iOS 9.0, *)) {
        NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
        NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
        
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes 
                                                   modifiedSince:dateFrom 
                                               completionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showSuccessAlert:@"Web缓存已清理"];
            });
        }];
    }
    
    // 清理 NSURLCache
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (void)clearImageCache {
    // 清理 SDWebImage 缓存（如果使用）
    Class sdImageCacheClass = NSClassFromString(@"SDImageCache");
    if (sdImageCacheClass) {
        id sharedCache = [sdImageCacheClass performSelector:@selector(sharedImageCache)];
        if ([sharedCache respondsToSelector:@selector(clearMemory)]) {
            [sharedCache performSelector:@selector(clearMemory)];
        }
        if ([sharedCache respondsToSelector:@selector(clearDiskOnCompletion:)]) {
            [sharedCache performSelector:@selector(clearDiskOnCompletion:) withObject:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showSuccessAlert:@"图片缓存已清理"];
                });
            }];
            return;
        }
    }
    
    // 清理默认图片缓存路径
    NSArray *cachesPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachesDirectory = cachesPaths.firstObject;
    NSString *imageCachePath = [cachesDirectory stringByAppendingPathComponent:@"ImageCache"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:imageCachePath]) {
        [self clearDirectoryContents:imageCachePath];
    } else {
        [self showSuccessAlert:@"图片缓存已清理"];
    }
}

- (void)clearUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *defaultsDict = [defaults dictionaryRepresentation];
    
    NSUInteger keysCount = defaultsDict.count;
    
    for (NSString *key in defaultsDict.allKeys) {
        [defaults removeObjectForKey:key];
    }
    [defaults synchronize];
    
    NSString *message = [NSString stringWithFormat:@"已清理 %lu 个偏好设置", (unsigned long)keysCount];
    [self showSuccessAlert:message];
}

- (void)clearKeychain {
    // 清理钥匙串（需要谨慎操作）
    NSArray *secClasses = @[
        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecClassInternetPassword,
        (__bridge id)kSecClassCertificate,
        (__bridge id)kSecClassKey,
        (__bridge id)kSecClassIdentity
    ];
    
    NSUInteger clearedItems = 0;
    
    for (id secClass in secClasses) {
        NSDictionary *spec = @{(__bridge id)kSecClass: secClass};
        OSStatus result = SecItemDelete((__bridge CFDictionaryRef)spec);
        if (result == errSecSuccess) {
            clearedItems++;
        }
    }
    
    NSString *message = [NSString stringWithFormat:@"钥匙串清理完成，处理了 %lu 种类型", (unsigned long)clearedItems];
    [self showSuccessAlert:message];
}

- (uint64_t)estimateWebCacheSize {
    // 估算Web缓存大小（简单估算，实际实现会更复杂）
    NSURLCache *cache = [NSURLCache sharedURLCache];
    return cache.currentDiskUsage;
}

- (uint64_t)estimateImageCacheSize {
    // 估算图片缓存大小
    NSArray *cachesPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachesDirectory = cachesPaths.firstObject;
    NSString *imageCachePath = [cachesDirectory stringByAppendingPathComponent:@"ImageCache"];
    
    return [self calculateDirectorySize:imageCachePath];
}

- (uint64_t)estimateUserDefaultsSize {
    // 估算用户偏好设置大小
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *defaultsDict = [defaults dictionaryRepresentation];
    
    NSError *error = nil;
    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:defaultsDict
                                                                  format:NSPropertyListBinaryFormat_v1_0
                                                                 options:0
                                                                   error:&error];
    
    return error ? 0 : plistData.length;
}

- (NSString *)formatBytes:(uint64_t)bytes {
    if (bytes < 1024) {
        return [NSString stringWithFormat:@"%llu B", bytes];
    } else if (bytes < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f KB", (double)bytes / 1024];
    } else if (bytes < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f MB", (double)bytes / (1024 * 1024)];
    } else {
        return [NSString stringWithFormat:@"%.2f GB", (double)bytes / (1024 * 1024 * 1024)];
    }
}

- (void)showSuccessAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清理完成" 
                                                                   message:message 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" 
                                                      style:UIAlertActionStyleDefault 
                                                    handler:nil];
    [alert addAction:okAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.cacheOptions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CacheCell" forIndexPath:indexPath];
    
    NSDictionary *option = self.cacheOptions[indexPath.row];
    NSString *title = option[@"title"];
    
    cell.textLabel.text = title;
    cell.detailTextLabel.text = [self formattedSizeForOption:title];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *option = self.cacheOptions[indexPath.row];
    
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title([NSString stringWithFormat:@"清除%@", option[@"title"]]);
        make.message([NSString stringWithFormat:@"确定要清除%@吗？此操作不可撤销。", option[@"title"]]);
        
        make.button(@"清除").destructiveStyle().handler(^(NSArray<NSString *> *strings) {
            [self clearCache:option];
        });
        
        make.button(@"取消").cancelStyle();
    } showFrom:self];
}

@end