#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FLEXDoKitLogEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLEXDoKitLogViewer : NSObject

// 单例方法
+ (instancetype)sharedInstance;
+ (instancetype)sharedViewer;

// 日志属性
@property (nonatomic, strong, readonly) NSArray<FLEXDoKitLogEntry *> *logEntries;
@property (nonatomic, strong) NSArray<FLEXDoKitLogEntry *> *filteredLogs;
@property (nonatomic, assign) FLEXDoKitLogLevel minimumLogLevel;
@property (nonatomic, strong) NSString *searchText;

// 筛选方法
- (void)applyFiltersWithLevel:(FLEXDoKitLogLevel)level searchText:(NSString *)searchText;
- (void)resetFilters;

// 日志操作
- (void)clearLogs;
- (void)addLogWithLevel:(FLEXDoKitLogLevel)level message:(NSString *)message;

@end

NS_ASSUME_NONNULL_END