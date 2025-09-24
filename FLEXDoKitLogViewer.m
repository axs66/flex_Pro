#import "FLEXDoKitLogViewer.h"
#import "FLEXDoKitLogEntry.h"
#import "flex_fishhook.h"
#import "FLEXCompatibility.h"
#import <asl.h>
#import <sys/syslog.h>

@interface FLEXDoKitLogViewer ()
@property (nonatomic, strong) NSMutableArray<FLEXDoKitLogEntry *> *internalLogEntries;
@property (nonatomic, strong) dispatch_queue_t logQueue;
@property (nonatomic, assign) NSUInteger maxLogEntries;
@end

@implementation FLEXDoKitLogViewer

+ (instancetype)sharedViewer {
    static FLEXDoKitLogViewer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

// 添加缺失的sharedInstance方法 (与sharedViewer等效)
+ (instancetype)sharedInstance {
    return [self sharedViewer];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _internalLogEntries = [NSMutableArray array];
        _logQueue = dispatch_queue_create("com.flex.logviewer", DISPATCH_QUEUE_SERIAL);
        _maxLogEntries = 1000;
        
        [self setupSystemLogCapture];
    }
    return self;
}

- (void)setupSystemLogCapture {
    // 监听 NSLog 输出
    [self interceptNSLog];
    
    // 监听系统日志
    [self startSystemLogMonitoring];
}

- (void)interceptNSLog {
    // 这里使用 fishhook 来拦截 NSLog
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 暂时注释掉这一行来禁用 hook
        // struct flex_rebinding nslog_rebinding = {"NSLog", (void *)flex_replacement_NSLog, (void **)&flex_original_NSLog};
        // flex_rebind_symbols(&nslog_rebinding, 1);
    });
}

// 原始 NSLog 函数指针
static void (*flex_original_NSLog)(NSString *format, ...);

// 替换的 NSLog 函数
void flex_replacement_NSLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    
    // 调用原始 NSLog
    if (flex_original_NSLog) {
        flex_original_NSLog(format, args);
    }
    
    // 记录到我们的日志查看器
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    [[FLEXDoKitLogViewer sharedViewer] addLogEntry:message
                                             level:FLEXDoKitLogLevelInfo
                                               tag:@"NSLog"
                                          fileName:@"Unknown"
                                        lineNumber:nil
                                      functionName:@"NSLog"];
    
    va_end(args);
}

- (void)startSystemLogMonitoring {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        aslclient client = asl_open(NULL, NULL, ASL_OPT_STDERR);
        if (!client) {
            return;
        }
        
        aslmsg query = asl_new(ASL_TYPE_QUERY);
        if (!query) {
            asl_close(client);
            return;
        }
        
        // 只获取当前进程的日志
        NSString *pidString = [NSString stringWithFormat:@"%d", [[NSProcessInfo processInfo] processIdentifier]];
        asl_set_query(query, ASL_KEY_PID, [pidString UTF8String], ASL_QUERY_OP_EQUAL);
        
        aslresponse response = asl_search(client, query);
        if (response) {
            aslmsg message;
            while ((message = asl_next(response)) != NULL) {
                [self processSystemLogMessage:message];
            }
            asl_release(response);
        }
        
        asl_free(query);
        asl_close(client);
    });
}

- (void)processSystemLogMessage:(aslmsg)message {
    const char *messageText = asl_get(message, ASL_KEY_MSG);
    const char *levelString = asl_get(message, ASL_KEY_LEVEL);
    const char *timeString = asl_get(message, ASL_KEY_TIME);
    const char *senderString = asl_get(message, ASL_KEY_SENDER);
    
    if (!messageText) {
        return;
    }
    
    NSString *logMessage = @(messageText);
    NSString *sender = senderString ? @(senderString) : @"System";
    
    // 解析日志级别
    FLEXDoKitLogLevel logLevel = FLEXDoKitLogLevelInfo;
    if (levelString) {
        int level = atoi(levelString);
        switch (level) {
            case ASL_LEVEL_EMERG:
            case ASL_LEVEL_ALERT:
            case ASL_LEVEL_CRIT:
            case ASL_LEVEL_ERR:
                logLevel = FLEXDoKitLogLevelError;
                break;
            case ASL_LEVEL_WARNING:
                logLevel = FLEXDoKitLogLevelWarning;
                break;
            case ASL_LEVEL_NOTICE:
            case ASL_LEVEL_INFO:
                logLevel = FLEXDoKitLogLevelInfo;
                break;
            case ASL_LEVEL_DEBUG:
                logLevel = FLEXDoKitLogLevelDebug;
                break;
        }
    }
    
    // 解析时间戳
    NSDate *timestamp = [NSDate date];
    if (timeString) {
        NSTimeInterval timeInterval = atof(timeString);
        timestamp = [NSDate dateWithTimeIntervalSince1970:timeInterval];
    }
    
    [self addLogEntryWithMessage:logMessage
                           level:logLevel
                             tag:sender
                        fileName:@"System"
                      lineNumber:nil
                    functionName:@"system_log"
                       timestamp:timestamp];
}

- (void)addLogEntry:(NSString *)message
              level:(FLEXDoKitLogLevel)level
                tag:(NSString *)tag
           fileName:(NSString *)fileName
         lineNumber:(NSNumber *)lineNumber
       functionName:(NSString *)functionName {
    [self addLogEntryWithMessage:message
                           level:level
                             tag:tag
                        fileName:fileName
                      lineNumber:lineNumber
                    functionName:functionName
                       timestamp:[NSDate date]];
}

- (void)addLogEntryWithMessage:(NSString *)message
                         level:(FLEXDoKitLogLevel)level
                           tag:(NSString *)tag
                      fileName:(NSString *)fileName
                    lineNumber:(NSNumber *)lineNumber
                  functionName:(NSString *)functionName
                     timestamp:(NSDate *)timestamp {
    
    if (!message) {
        return;
    }
    
    FLEXDoKitLogEntry *entry = [[FLEXDoKitLogEntry alloc] init];
    entry.message = message;
    entry.level = level;
    entry.tag = tag ?: @"Unknown";
    entry.file = fileName;  // 使用file属性
    entry.fileName = fileName;  // 同时设置fileName属性
    entry.line = lineNumber ? lineNumber.integerValue : 0;  // 使用line属性
    entry.lineNumber = [lineNumber stringValue];  // 转换为字符串
    entry.functionName = functionName;
    entry.timestamp = timestamp;
    
    dispatch_async(self.logQueue, ^{
        [self.internalLogEntries addObject:entry];
        
        // 限制日志条目数量
        while (self.internalLogEntries.count > self.maxLogEntries) {
            [self.internalLogEntries removeObjectAtIndex:0];
        }
        
        // 发送通知
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitLogEntryAdded"
                                                                object:entry];
        });
    });
}

- (NSArray<FLEXDoKitLogEntry *> *)logEntries {
    __block NSArray *entries;
    dispatch_sync(self.logQueue, ^{
        entries = [self.internalLogEntries copy];
    });
    return entries;
}

- (void)clearLogs {
    dispatch_async(self.logQueue, ^{
        [self.internalLogEntries removeAllObjects];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitLogCleared"
                                                                object:nil];
        });
    });
}

- (NSArray<FLEXDoKitLogEntry *> *)logEntriesWithLevel:(FLEXDoKitLogLevel)level {
    NSArray *allEntries = [self logEntries];
    return [allEntries filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(FLEXDoKitLogEntry *entry, NSDictionary *bindings) {
        return entry.level == level;
    }]];
}

- (NSArray<FLEXDoKitLogEntry *> *)logEntriesContainingString:(NSString *)searchString {
    if (!searchString || searchString.length == 0) {
        return [self logEntries];
    }
    
    NSArray *allEntries = [self logEntries];
    return [allEntries filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(FLEXDoKitLogEntry *entry, NSDictionary *bindings) {
        return [entry.message.lowercaseString containsString:searchString.lowercaseString] ||
               [entry.tag.lowercaseString containsString:searchString.lowercaseString];
    }]];
}

// 添加缺失的过滤方法
- (void)applyFiltersWithLevel:(FLEXDoKitLogLevel)level searchText:(NSString *)searchText {
    NSArray *allEntries = [self logEntries];
    NSMutableArray *filtered = [NSMutableArray array];
    
    for (FLEXDoKitLogEntry *entry in allEntries) {
        // 应用日志级别过滤
        if (entry.level >= level) {
            // 应用搜索文本过滤
            if (!searchText || searchText.length == 0 ||
                [entry.message rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [entry.tag rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [filtered addObject:entry];
            }
        }
    }
    
    self.filteredLogs = filtered;
}

// 重置过滤条件
- (void)resetFilters {
    self.minimumLogLevel = FLEXDoKitLogLevelVerbose;
    self.searchText = @"";
    self.filteredLogs = [self logEntries];
}

// 简化的添加日志方法
- (void)addLogWithLevel:(FLEXDoKitLogLevel)level message:(NSString *)message {
    [self addLogEntry:message
                level:level
                  tag:@"Default"
             fileName:nil
           lineNumber:nil
         functionName:nil];
}

@end