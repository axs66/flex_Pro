//
// FLEX-DoKit.h
//

#import "FLEXDoKitViewController.h"
#import "FLEXDoKitNavigator.h"
#import "FLEXDoKitNetworkViewController.h"
#import "FLEXDoKitNetworkMonitor.h"
#import "FLEXDoKitFileBrowserViewController.h"
#import "FLEXDoKitDatabaseViewController.h"
#import "FLEXDoKitCrashViewController.h"
#import "FLEXDoKitCrashRecord.h"
#import "FLEXDoKitCleanViewController.h"
#import "FLEXDoKitLogViewController.h"
#import "FLEXDoKitLogViewer.h"
#import "FLEXDoKitPerformanceViewController.h"
#import "FLEXManager+DoKit.h"
#import "FLEXKeychainQuery.h"
#import "NSString+SyntaxColoring.h"

// 启用DoKit功能组
#define FLEXDoKitEnable() \
do { \
    [[FLEXManager sharedManager] setDoKitEnabled:YES]; \
    [[FLEXDoKitNavigator sharedNavigator] show]; \
} while(0)

// 禁用DoKit功能组
#define FLEXDoKitDisable() \
do { \
    [[FLEXManager sharedManager] setDoKitEnabled:NO]; \
    [[FLEXDoKitNavigator sharedNavigator] hide]; \
} while(0)

// 直接访问核心功能
#define FLEXDoKitShowNavigator() [[FLEXDoKitNavigator sharedNavigator] show]
#define FLEXDoKitHideNavigator() [[FLEXDoKitNavigator sharedNavigator] hide]

// 启用网络监控
#define FLEXDoKitStartNetworkMonitoring() [[[FLEXManager sharedManager] networkMonitor] startMonitoring]
#define FLEXDoKitStopNetworkMonitoring() [[[FLEXManager sharedManager] networkMonitor] stopMonitoring]

// 日志记录
#define FLEXDoKitLogError(tag, format, ...) NSLog(@"[ERROR] %@: %@", tag, [NSString stringWithFormat:format, ##__VA_ARGS__])
#define FLEXDoKitLogWarning(tag, format, ...) FLEXLogWarning(tag, format, ##__VA_ARGS__) 
#define FLEXDoKitLogInfo(tag, format, ...) FLEXLogInfo(tag, format, ##__VA_ARGS__)
#define FLEXDoKitLogDebug(tag, format, ...) FLEXLogDebug(tag, format, ##__VA_ARGS__)

// 注册崩溃监控处理器
#define FLEXDoKitRegisterCrashHandler() \
do { \
    NSSetUncaughtExceptionHandler(&FLEXDoKitUncaughtExceptionHandler); \
} while(0)

// 崩溃处理函数
NS_INLINE void FLEXDoKitUncaughtExceptionHandler(NSException *exception) { \
    FLEXDoKitCrashRecord *record = [FLEXDoKitCrashRecord recordWithException:exception additionalInfo:nil]; \
    NSMutableArray *records = [[FLEXDoKitCrashRecord loadRecordsFromDisk] mutableCopy] ?: [NSMutableArray array]; \
    [records addObject:[record toDictionary]]; \
    [FLEXDoKitCrashRecord saveRecordsToDisk:records]; \
}