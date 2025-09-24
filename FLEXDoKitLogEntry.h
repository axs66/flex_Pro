#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FLEXDoKitLogLevel) {
    FLEXDoKitLogLevelVerbose = 0,  // 添加 Verbose 级别作为最低级别
    FLEXDoKitLogLevelDebug,
    FLEXDoKitLogLevelInfo,
    FLEXDoKitLogLevelWarning,
    FLEXDoKitLogLevelError,
    FLEXDoKitLogLevelFatal      // 添加 Fatal 级别作为最高级别
};

@interface FLEXDoKitLogEntry : NSObject

@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, assign) FLEXDoKitLogLevel level;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) NSString *tag;
@property (nonatomic, copy) NSString *file;
@property (nonatomic, assign) NSInteger line;
@property (nonatomic, copy) NSString *functionName;
@property (nonatomic, copy) NSString *category;
// 添加新属性以匹配代码中的使用
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *lineNumber;

// 添加便利方法
+ (instancetype)entryWithMessage:(NSString *)message level:(FLEXDoKitLogLevel)level;
- (NSString *)levelString;

@end

NS_ASSUME_NONNULL_END