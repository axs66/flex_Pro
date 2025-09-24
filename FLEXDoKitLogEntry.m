#import "FLEXDoKitLogEntry.h"

@implementation FLEXDoKitLogEntry

+ (instancetype)entryWithMessage:(NSString *)message level:(FLEXDoKitLogLevel)level {
    FLEXDoKitLogEntry *entry = [[self alloc] init];
    entry.message = message;
    entry.level = level;
    entry.timestamp = [NSDate date];
    entry.tag = @"";
    entry.file = @"";
    entry.fileName = @"";
    entry.line = 0;
    entry.lineNumber = @"";
    entry.category = @"";
    return entry;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // ✅ 设置默认值
        _message = @"";
        _level = FLEXDoKitLogLevelInfo;
        _timestamp = [NSDate date];
        _category = @"";
        _tag = @"";
        _file = @"";
        _line = 0;
    }
    return self;
}

- (NSString *)description {
    NSString *levelString;
    switch (self.level) {
        case FLEXDoKitLogLevelVerbose:
            levelString = @"VERBOSE";
            break;
        case FLEXDoKitLogLevelDebug:
            levelString = @"DEBUG";
            break;
        case FLEXDoKitLogLevelInfo:
            levelString = @"INFO";
            break;
        case FLEXDoKitLogLevelWarning:
            levelString = @"WARNING";
            break;
        case FLEXDoKitLogLevelError:
            levelString = @"ERROR";
            break;
        case FLEXDoKitLogLevelFatal:
            levelString = @"FATAL";
            break;
    }
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss.SSS";
    NSString *timeString = [formatter stringFromDate:self.timestamp];
    
    return [NSString stringWithFormat:@"[%@] %@ <%@> %@", timeString, levelString, self.tag, self.message];
}

// 添加缺失的 levelString 方法实现
- (NSString *)levelString {
    switch (self.level) {
        case FLEXDoKitLogLevelVerbose:
            return @"VERBOSE";
        case FLEXDoKitLogLevelDebug:
            return @"DEBUG";
        case FLEXDoKitLogLevelInfo:
            return @"INFO";
        case FLEXDoKitLogLevelWarning:
            return @"WARN";
        case FLEXDoKitLogLevelError:
            return @"ERROR";
        case FLEXDoKitLogLevelFatal:
            return @"FATAL";
        default:
            return @"UNKNOWN";
    }
}

@end