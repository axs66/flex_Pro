#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 崩溃记录类，表示一条应用崩溃信息
@interface FLEXDoKitCrashRecord : NSObject

/// 崩溃发生的时间戳
@property (nonatomic, strong) NSDate *timestamp;

/// 崩溃类型名称
@property (nonatomic, strong) NSString *exceptionName;

/// 崩溃原因
@property (nonatomic, strong) NSString *exceptionReason;

/// 堆栈信息
@property (nonatomic, strong) NSArray *callStackSymbols;

/// 其他崩溃信息（设备、系统版本等）
@property (nonatomic, strong) NSDictionary *additionalInfo;

/// 添加缺失的属性
@property (nonatomic, strong) NSString *reason;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, strong) NSArray *callStack;
@property (nonatomic, strong) NSDictionary *deviceInfo;
@property (nonatomic, strong) NSDictionary *appInfo;

/// 初始化崩溃记录
/// @param exception 异常对象
/// @param additionalInfo 附加信息
+ (instancetype)recordWithException:(NSException *)exception additionalInfo:(nullable NSDictionary *)additionalInfo;

/// 获取崩溃记录数组
+ (NSArray<FLEXDoKitCrashRecord *> *)allRecords;

/// 清除所有崩溃记录
+ (void)clearAllRecords;

/// 记录当前所有崩溃记录到磁盘
+ (void)saveRecordsToDisk:(NSArray *)records;

/// 从磁盘加载崩溃记录
+ (NSArray *)loadRecordsFromDisk;

/// 获取崩溃记录文件路径
+ (NSString *)crashRecordsFilePath;

/// 转换为字典
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END