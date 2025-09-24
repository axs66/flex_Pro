//
//  FLEXDoKitNetworkMonitor.m
//  FLEX
//
//  DoKit网络监控器实现
//

#import "FLEXDoKitNetworkMonitor.h"

@interface FLEXDoKitNetworkMonitor ()
@property (nonatomic, strong) NSMutableArray *mockRules;
@property (nonatomic, assign) BOOL mockModeEnabled;
@end

@implementation FLEXDoKitNetworkMonitor

+ (instancetype)sharedInstance {
    static FLEXDoKitNetworkMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _networkRequests = [NSMutableArray array];
        _mockRules = [NSMutableArray array];
        _monitoring = NO;
        _mockModeEnabled = NO;
        _networkDelay = 0.0;
        _errorRate = 0.0;
    }
    return self;
}

- (void)startMonitoring {
    if (!_monitoring) {
        _monitoring = YES;
        NSLog(@"网络监控已启动");
    }
}

- (void)stopMonitoring {
    if (_monitoring) {
        _monitoring = NO;
        NSLog(@"网络监控已停止");
    }
}

- (void)toggleNetworkMonitoring {
    if (_monitoring) {
        [self stopMonitoring];
    } else {
        [self startMonitoring];
    }
}

- (BOOL)isMonitoring {
    return _monitoring;
}

- (NSArray *)currentNetworkRequests {
    return [_networkRequests copy];
}

- (void)clearNetworkRequests {
    [_networkRequests removeAllObjects];
}

// 添加Mock规则
- (void)addMockRule:(NSDictionary *)rule {
    if (rule) {
        [_mockRules addObject:rule];
    }
}

// 删除Mock规则
- (void)removeMockRule:(NSDictionary *)rule {
    [_mockRules removeObject:rule];
}

// 清除所有Mock规则
- (void)clearMockRules {
    [_mockRules removeAllObjects];
}

// 记录网络请求
- (void)recordNetworkRequest:(NSURLRequest *)request
                    response:(NSURLResponse *)response
                        data:(NSData *)data
                       error:(NSError *)error
                   startTime:(NSDate *)startTime {
    
    if (!request) return;
    
    NSMutableDictionary *requestInfo = [NSMutableDictionary dictionary];
    requestInfo[@"url"] = request.URL.absoluteString ?: @"";
    requestInfo[@"method"] = request.HTTPMethod ?: @"GET";
    
    if (response) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        requestInfo[@"statusCode"] = @(httpResponse.statusCode);
        requestInfo[@"MIMEType"] = httpResponse.MIMEType ?: @"";
    }
    
    if (error) {
        requestInfo[@"error"] = error.localizedDescription;
    }
    
    if (data) {
        requestInfo[@"responseSize"] = @(data.length);
        // 尝试解析JSON
        id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (jsonObject) {
            requestInfo[@"responseJSON"] = jsonObject;
        } else {
            // 如果不是JSON，存储为字符串
            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (responseString) {
                requestInfo[@"responseString"] = responseString;
            }
        }
    }
    
    if (startTime) {
        NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:startTime];
        requestInfo[@"duration"] = @(duration);
    }
    
    requestInfo[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
    
    // 添加到请求历史
    [_networkRequests addObject:requestInfo];
    
    // 发送通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitNetworkRequestRecorded" 
                                                        object:nil
                                                      userInfo:requestInfo];
}

// 模拟弱网络
- (void)simulateSlowNetwork:(float)delayInSeconds {
    _networkDelay = delayInSeconds;
    NSLog(@"已设置网络延迟: %.2f秒", delayInSeconds);
}

// 模拟网络错误
- (void)simulateNetworkError {
    _errorRate = 1.0; // 100%错误率
    NSLog(@"已设置网络错误模拟");
}

// 重置网络模拟
- (void)resetNetworkSimulation {
    _networkDelay = 0.0;
    _errorRate = 0.0;
    NSLog(@"已重置网络模拟设置");
}

// 处理Mock请求
- (BOOL)handleRequestIfMocked:(id)request {
    if (!_mockModeEnabled || _mockRules.count == 0) {
        return NO;
    }
    
    // 获取请求URL
    NSURL *requestURL = nil;
    if ([request respondsToSelector:@selector(URL)]) {
        requestURL = [request URL];
    }
    
    NSString *urlString = requestURL.absoluteString ?: @"";
    
    // 查找匹配的Mock规则
    for (NSDictionary *rule in _mockRules) {
        NSString *mockURLPattern = rule[@"url"];
        if ([urlString rangeOfString:mockURLPattern].location != NSNotFound) {
            NSLog(@"找到匹配的Mock规则: %@", mockURLPattern);
            return YES;
        }
    }
    
    return NO;
}

// 启用Mock模式
- (void)enableMockMode {
    _mockModeEnabled = YES;
    NSLog(@"已启用Mock模式");
}

// 禁用Mock模式
- (void)disableMockMode {
    _mockModeEnabled = NO;
    NSLog(@"已禁用Mock模式");
}

@end