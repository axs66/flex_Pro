@interface RTBClassLoadAnalyzer : NSObject

+ (instancetype)sharedInstance;

// 开始记录类加载信息
- (void)startRecording;

// 停止记录
- (void)stopRecording;

// 获取类加载顺序和时间信息
- (NSArray *)getLoadedClassesInfo;

@end

@implementation RTBClassLoadAnalyzer {
    NSMutableArray *_loadedClasses;
    CFAbsoluteTime _startTime;
    BOOL _isRecording;
}

+ (void)load {
    [self sharedInstance];
}

+ (instancetype)sharedInstance {
    static RTBClassLoadAnalyzer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RTBClassLoadAnalyzer alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _loadedClasses = [NSMutableArray array];
        _isRecording = NO;
        
        // 注册类加载通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(handleClassLoad:)
                                                   name:@"NSBundleDidLoadNotification"
                                                 object:nil];
    }
    return self;
}

- (void)startRecording {
    _startTime = CFAbsoluteTimeGetCurrent();
    _isRecording = YES;
}

- (void)handleClassLoad:(NSNotification *)notification {
    if (!_isRecording) return;
    
    NSBundle *bundle = notification.object;
    CFAbsoluteTime loadTime = CFAbsoluteTimeGetCurrent() - _startTime;
    
    // 获取bundle中的所有类
    unsigned int count = 0;
    const char **classes = objc_copyClassNamesForImage(bundle.executablePath.UTF8String, &count);
    
    for (unsigned int i = 0; i < count; i++) {
        Class cls = objc_getClass(classes[i]);
        [_loadedClasses addObject:@{
            @"class": NSStringFromClass(cls),
            @"time": @(loadTime),
            @"bundle": bundle.bundleIdentifier ?: @"Unknown"
        }];
    }
    
    free(classes);
}

- (NSArray *)getLoadedClassesInfo {
    return [_loadedClasses copy];
}

@end