#import "RTBNetworkMonitor.h"
#import "NSURLRequest+Doraemon.h"
#import "NSObject+Doraemon.h"
#import <objc/runtime.h>

@implementation RTBNetworkRequest
// 实现网络请求记录对象
@end

// 定义 RTBNetworkProtocol 类
@interface RTBNetworkProtocol : NSURLProtocol <NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, strong) NSURLResponse *response;
@end

@interface RTBNetworkMonitor ()
@property (nonatomic, strong) NSMutableArray<RTBNetworkRequest *> *networkRequests;
@property (nonatomic, assign) BOOL isMonitoring;
@end

@implementation RTBNetworkMonitor

+ (instancetype)sharedInstance {
    static RTBNetworkMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RTBNetworkMonitor alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _networkRequests = [NSMutableArray array];
        _isMonitoring = NO;
    }
    return self;
}

- (void)startNetworkMonitoring {
    if (self.isMonitoring) return;
    
    self.isMonitoring = YES;
    
    // 使用NSURLProtocol进行网络监控
    [self swizzleNSURLSessionMethods];
    
    // 注册协议类
    [NSURLProtocol registerClass:[RTBNetworkProtocol class]];
    
    NSLog(@"RTBNetworkMonitor: 网络监控已启动");
}

- (void)stopNetworkMonitoring {
    if (!self.isMonitoring) return;
    
    self.isMonitoring = NO;
    
    // 取消注册协议类
    [NSURLProtocol unregisterClass:[RTBNetworkProtocol class]];
    
    NSLog(@"RTBNetworkMonitor: 网络监控已停止");
}

- (void)swizzleNSURLSessionMethods {
    // 交换NSURLSessionConfiguration方法
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [NSURLSessionConfiguration class];
        [cls doraemon_swizzleClassMethodWithOriginSel:@selector(defaultSessionConfiguration) 
                                          swizzledSel:@selector(rtb_defaultSessionConfiguration)];
    });
}

+ (NSURLSessionConfiguration *)rtb_defaultSessionConfiguration {
    NSURLSessionConfiguration *configuration = [self rtb_defaultSessionConfiguration];
    
    // 添加自定义的网络拦截器
    NSMutableArray *protocolClasses = [configuration.protocolClasses mutableCopy];
    if (!protocolClasses) {
        protocolClasses = [NSMutableArray array];
    }
    
    // 插入RTBNetworkProtocol类
    Class protocolClass = [RTBNetworkProtocol class];
    if (![protocolClasses containsObject:protocolClass]) {
        [protocolClasses insertObject:protocolClass atIndex:0];
    }
    configuration.protocolClasses = protocolClasses;
    
    return configuration;
}

- (void)recordRequestStart:(NSURLRequest *)request {
    if (!request) return;
    
    RTBNetworkRequest *networkRequest = [[RTBNetworkRequest alloc] init];
    networkRequest.requestId = request.rtb_requestId ?: [[NSUUID UUID] UUIDString];
    networkRequest.url = request.URL;
    networkRequest.method = request.HTTPMethod ?: @"GET";
    networkRequest.headers = request.allHTTPHeaderFields;
    networkRequest.requestBody = request.HTTPBody;
    networkRequest.startTime = [[NSDate date] timeIntervalSince1970];
    
    @synchronized (self.networkRequests) {
        [self.networkRequests addObject:networkRequest];
    }
}

- (void)recordRequestFinished:(NSString *)requestId 
                   statusCode:(NSInteger)statusCode 
                  responseBody:(NSData *)responseBody {
    if (!requestId) return;
    
    RTBNetworkRequest *request = [self findRequestById:requestId];
    if (request) {
        request.endTime = [[NSDate date] timeIntervalSince1970];
        request.statusCode = statusCode;
        request.responseBody = responseBody;
        request.responseSize = responseBody.length;
    }
}

- (RTBNetworkRequest *)findRequestById:(NSString *)requestId {
    if (!requestId) return nil;
    
    @synchronized (self.networkRequests) {
        for (RTBNetworkRequest *request in self.networkRequests) {
            if ([request.requestId isEqualToString:requestId]) {
                return request;
            }
        }
    }
    return nil;
}

- (NSArray<RTBNetworkRequest *> *)getAllNetworkRequests {
    @synchronized (self.networkRequests) {
        return [self.networkRequests copy];
    }
}

- (NSArray<RTBNetworkRequest *> *)getNetworkRequestsWithFilter:(NSPredicate *)filter {
    if (!filter) return [self getAllNetworkRequests];
    
    @synchronized (self.networkRequests) {
        return [self.networkRequests filteredArrayUsingPredicate:filter];
    }
}

- (void)clearNetworkRecords {
    @synchronized (self.networkRequests) {
        [self.networkRequests removeAllObjects];
    }
}

@end

#pragma mark - RTBNetworkProtocol 实现

@implementation RTBNetworkProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    // 检查是否已处理该请求
    if ([NSURLProtocol propertyForKey:@"RTBNetworkProtocol" inRequest:request]) {
        return NO;
    }
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSMutableURLRequest *mRequest = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"RTBNetworkProtocol" inRequest:mRequest];
    
    // 设置唯一标识符和开始时间
    [mRequest setRtb_requestId:[[NSUUID UUID] UUIDString]];
    [mRequest setRtb_startTime:@([[NSDate date] timeIntervalSince1970] * 1000)];
    
    // 记录请求开始
    [[RTBNetworkMonitor sharedInstance] recordRequestStart:mRequest];
    
    // 创建和启动连接
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                          delegate:self
                                                     delegateQueue:[NSOperationQueue mainQueue]];
    self.dataTask = [session dataTaskWithRequest:mRequest];
    [self.dataTask resume];
}

- (void)stopLoading {
    [self.dataTask cancel];
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    self.response = response;
    self.responseData = [NSMutableData data];
    
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
    [self.client URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSInteger statusCode = 0;
    if ([self.response isKindOfClass:[NSHTTPURLResponse class]]) {
        statusCode = [(NSHTTPURLResponse *)self.response statusCode];
    }
    
    NSString *requestId = [self.request rtb_requestId];
    if (!error) {
        [[RTBNetworkMonitor sharedInstance] recordRequestFinished:requestId 
                                                      statusCode:statusCode 
                                                   responseBody:self.responseData];
        [self.client URLProtocolDidFinishLoading:self];
    } else {
        [self.client URLProtocol:self didFailWithError:error];
    }
}

@end