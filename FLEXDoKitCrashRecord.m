#import "FLEXDoKitCrashRecord.h"
#import <UIKit/UIKit.h>

@implementation FLEXDoKitCrashRecord

+ (instancetype)recordWithException:(NSException *)exception additionalInfo:(nullable NSDictionary *)additionalInfo {
    FLEXDoKitCrashRecord *record = [[FLEXDoKitCrashRecord alloc] init];
    record.exceptionName = exception.name;
    record.exceptionReason = exception.reason;
    record.callStackSymbols = exception.callStackSymbols;
    record.timestamp = [NSDate date];
    record.additionalInfo = additionalInfo ?: @{};
    
    // 设置其他属性
    record.reason = exception.reason;
    record.type = exception.name;
    record.callStack = exception.callStackSymbols;
    
    // 设备信息
    NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionary];
    UIDevice *device = [UIDevice currentDevice];
    deviceInfo[@"model"] = device.model;
    deviceInfo[@"systemName"] = device.systemName;
    deviceInfo[@"systemVersion"] = device.systemVersion;
    record.deviceInfo = deviceInfo;
    
    // 应用信息
    NSMutableDictionary *appInfo = [NSMutableDictionary dictionary];
    NSBundle *mainBundle = [NSBundle mainBundle];
    appInfo[@"bundleIdentifier"] = mainBundle.bundleIdentifier;
    appInfo[@"version"] = [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    appInfo[@"build"] = [mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    record.appInfo = appInfo;
    
    return record;
}

+ (NSArray<FLEXDoKitCrashRecord *> *)allRecords {
    NSArray *rawRecords = [self loadRecordsFromDisk];
    NSMutableArray *records = [NSMutableArray arrayWithCapacity:rawRecords.count];
    
    for (NSDictionary *dict in rawRecords) {
        FLEXDoKitCrashRecord *record = [[FLEXDoKitCrashRecord alloc] init];
        record.exceptionName = dict[@"exceptionName"];
        record.exceptionReason = dict[@"exceptionReason"];
        record.callStackSymbols = dict[@"callStackSymbols"];
        record.additionalInfo = dict[@"additionalInfo"];
        record.reason = dict[@"reason"];
        record.type = dict[@"type"];
        record.callStack = dict[@"callStack"];
        record.deviceInfo = dict[@"deviceInfo"];
        record.appInfo = dict[@"appInfo"];
        
        // 解析时间戳
        if ([dict[@"timestamp"] isKindOfClass:[NSNumber class]]) {
            NSTimeInterval timestamp = [dict[@"timestamp"] doubleValue];
            record.timestamp = [NSDate dateWithTimeIntervalSince1970:timestamp];
        } else if ([dict[@"timestamp"] isKindOfClass:[NSDate class]]) {
            record.timestamp = dict[@"timestamp"];
        } else {
            record.timestamp = [NSDate date];
        }
        
        [records addObject:record];
    }
    
    // 按时间戳降序排序
    [records sortUsingComparator:^NSComparisonResult(FLEXDoKitCrashRecord *record1, FLEXDoKitCrashRecord *record2) {
        return [record2.timestamp compare:record1.timestamp];
    }];
    
    return records;
}

+ (void)clearAllRecords {
    [self saveRecordsToDisk:@[]];
}

+ (NSArray *)loadRecordsFromDisk {
    NSString *filePath = [self crashRecordsFilePath];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    if (!data) {
        return @[];
    }
    
    NSError *error;
    NSArray *records = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        NSLog(@"读取崩溃记录失败: %@", error.localizedDescription);
        return @[];
    }
    
    return records;
}

+ (void)saveRecordsToDisk:(NSArray *)records {
    NSData *data = [NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted error:nil];
    if (!data) {
        return;
    }
    
    NSString *filePath = [self crashRecordsFilePath];
    [data writeToFile:filePath atomically:YES];
}

+ (NSString *)crashRecordsFilePath {
    NSString *documentsDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [documentsDirectory stringByAppendingPathComponent:@"FLEXDoKitCrashRecords.json"];
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"timestamp"] = @([self.timestamp timeIntervalSince1970]);
    dict[@"exceptionName"] = self.exceptionName ?: @"";
    dict[@"exceptionReason"] = self.exceptionReason ?: @"";
    dict[@"callStackSymbols"] = self.callStackSymbols ?: @[];
    dict[@"additionalInfo"] = self.additionalInfo ?: @{};
    
    // 添加其他属性
    dict[@"reason"] = self.reason ?: @"";
    dict[@"type"] = self.type ?: @"";
    dict[@"callStack"] = self.callStack ?: @[];
    dict[@"deviceInfo"] = self.deviceInfo ?: @{};
    dict[@"appInfo"] = self.appInfo ?: @{};
    
    return dict;
}

@end