@interface RTBMethodProfiler : NSObject

@property (nonatomic, strong) NSMutableDictionary *methodCallStats;
@property (nonatomic, assign) BOOL isRecording;

+ (instancetype)sharedInstance;
- (void)startRecording;
- (void)stopRecording;
- (NSDictionary *)getMethodCallStats;

@end