#import <Foundation/Foundation.h>

@interface RTBNetworkRequest : NSObject
@property (nonatomic, strong) NSString *requestId;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSString *method;
@property (nonatomic, strong) NSDictionary *headers;
@property (nonatomic, strong) NSData *requestBody;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) NSTimeInterval endTime;
@property (nonatomic, assign) NSInteger statusCode;
@property (nonatomic, strong) NSData *responseBody;
@property (nonatomic, assign) NSInteger responseSize;
@end

@interface RTBNetworkMonitor : NSObject

+ (instancetype)sharedInstance;

// 网络监控开关
- (void)startNetworkMonitoring;
- (void)stopNetworkMonitoring;

// 获取网络请求记录
- (NSArray<RTBNetworkRequest *> *)getAllNetworkRequests;
- (NSArray<RTBNetworkRequest *> *)getNetworkRequestsWithFilter:(NSPredicate *)filter;

// 清空记录
- (void)clearNetworkRecords;

@end